unit SYNC_PianoRoll_Horizontal3DDisplay;

// 時間をX、音階をY、実厚みをZへ割り当てる横3D表示を実装する。

interface

uses
  AviUtl2FilterTypes,
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_MusicData;

function DrawHorizontalPianoRoll3D(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings): Boolean;

implementation

uses
  System.Math,
  SYNC_PianoRoll_Colors,
  SYNC_PianoRoll_PianoKeys,
  SYNC_PianoRoll_PitchFollow;

const
  MAX_QUAD_COUNT = 65536;

type
  TVertexColorArray = array of TVERTEX_COLOR;

procedure SetVertex(var Vertex: TVERTEX_COLOR; X, Y, Z: Single;
  const Color: TPianoRollColor);
begin
  Vertex.X := X;
  Vertex.Y := Y;
  Vertex.Z := Z;
  Vertex.R := Color.R / 255.0;
  Vertex.G := Color.G / 255.0;
  Vertex.B := Color.B / 255.0;
  Vertex.A := Color.A / 255.0;
end;

function ShadeColor(const Color: TPianoRollColor;
  Brightness: Double): TPianoRollColor;
begin
  Result := PianoRollColor(
    Round(Color.R * EnsureRange(Brightness, 0.0, 1.0)),
    Round(Color.G * EnsureRange(Brightness, 0.0, 1.0)),
    Round(Color.B * EnsureRange(Brightness, 0.0, 1.0)), Color.A);
end;

procedure ResolvePlanePoint(TimeOffset, DisplayTime, TimeAxisLength, BaseX,
  Height: Double; out X, Z: Single);
var
  TimePosition: Double;
begin
  TimePosition := TimeOffset / DisplayTime * TimeAxisLength;
  // 正面では2D横と同様に未来が右へ進み、厚みだけをZへ割り当てる。
  X := BaseX + TimePosition;
  Z := -Height;
end;

procedure EnsureVertexCapacity(var Vertices: TVertexColorArray;
  RequiredCount: Integer);
begin
  if RequiredCount > Length(Vertices) then
    SetLength(Vertices, Min(MAX_QUAD_COUNT * 4,
      Max(1024, Length(Vertices) * 2)));
end;

procedure AppendPlaneQuadAtHeight(var Vertices: TVertexColorArray;
  var VertexCount: Integer; Y0, Y1, Time0, Time1, DisplayTime,
  TimeAxisLength, BaseX, Height: Double;
  const Color: TPianoRollColor);
var
  RequiredCount: Integer;
  X0, X1, Z0, Z1: Single;
begin
  if (VertexCount div 4 >= MAX_QUAD_COUNT) or
    (Y1 <= Y0) or (Time1 <= Time0) then
    Exit;
  RequiredCount := VertexCount + 4;
  EnsureVertexCapacity(Vertices, RequiredCount);

  ResolvePlanePoint(Time0, DisplayTime, TimeAxisLength, BaseX,
    Height, X0, Z0);
  ResolvePlanePoint(Time1, DisplayTime, TimeAxisLength, BaseX,
    Height, X1, Z1);
  SetVertex(Vertices[VertexCount], X0, Y0, Z0, Color);
  SetVertex(Vertices[VertexCount + 1], X1, Y0, Z1, Color);
  SetVertex(Vertices[VertexCount + 2], X1, Y1, Z1, Color);
  SetVertex(Vertices[VertexCount + 3], X0, Y1, Z0, Color);
  Inc(VertexCount, 4);
end;

procedure AppendHeightQuad(var Vertices: TVertexColorArray;
  var VertexCount: Integer; Y0, Y1, Time0, Time1, Height0, Height1,
  DisplayTime, TimeAxisLength, BaseX: Double; const Color: TPianoRollColor);
var
  X00, X01, X10, X11, Z00, Z01, Z10, Z11: Single;
begin
  if (VertexCount div 4 >= MAX_QUAD_COUNT) then
    Exit;
  EnsureVertexCapacity(Vertices, VertexCount + 4);
  ResolvePlanePoint(Time0, DisplayTime, TimeAxisLength, BaseX,
    Height0, X00, Z00);
  ResolvePlanePoint(Time1, DisplayTime, TimeAxisLength, BaseX,
    Height0, X01, Z01);
  ResolvePlanePoint(Time1, DisplayTime, TimeAxisLength, BaseX,
    Height1, X11, Z11);
  ResolvePlanePoint(Time0, DisplayTime, TimeAxisLength, BaseX,
    Height1, X10, Z10);
  SetVertex(Vertices[VertexCount], X00, Y0, Z00, Color);
  SetVertex(Vertices[VertexCount + 1], X01, Y1, Z01, Color);
  SetVertex(Vertices[VertexCount + 2], X11, Y1, Z11, Color);
  SetVertex(Vertices[VertexCount + 3], X10, Y0, Z10, Color);
  Inc(VertexCount, 4);
end;

procedure AppendExtrudedBox(var Vertices: TVertexColorArray;
  var VertexCount: Integer; Y0, Y1, Time0, Time1, DisplayTime,
  TimeAxisLength, BaseX, SurfaceHeight, Thickness: Double;
  GrowTowardViewer: Boolean;
  const Color: TPianoRollColor);
var
  BaseHeight: Double;
  SideColor, EndColor: TPianoRollColor;
  TopHeight: Double;
begin
  if (Y1 <= Y0) or (Time1 <= Time0) then
    Exit;
  Thickness := Max(0.0, Thickness);
  if GrowTowardViewer then
  begin
    BaseHeight := SurfaceHeight;
    TopHeight := SurfaceHeight + Thickness;
  end
  else
  begin
    // 上面を固定し、厚みはカメラから遠い背面Zへ伸ばす。
    BaseHeight := SurfaceHeight - Thickness;
    TopHeight := SurfaceHeight;
  end;
  if Thickness <= 0.0 then
  begin
    AppendPlaneQuadAtHeight(Vertices, VertexCount, Y0, Y1, Time0, Time1,
      DisplayTime, TimeAxisLength, BaseX, TopHeight, Color);
    Exit;
  end;

  SideColor := ShadeColor(Color, 0.62);
  EndColor := ShadeColor(Color, 0.48);
  // 奥側端面を省き、左右・手前側面の後へ上面を置いて表面の重なりを安定させる。
  AppendHeightQuad(Vertices, VertexCount, Y0, Y0, Time0, Time1,
    BaseHeight, TopHeight, DisplayTime, TimeAxisLength, BaseX, SideColor);
  AppendHeightQuad(Vertices, VertexCount, Y1, Y1, Time1, Time0,
    BaseHeight, TopHeight, DisplayTime, TimeAxisLength, BaseX, SideColor);
  AppendHeightQuad(Vertices, VertexCount, Y1, Y0, Time0, Time0,
    BaseHeight, TopHeight, DisplayTime, TimeAxisLength, BaseX, EndColor);
  AppendPlaneQuadAtHeight(Vertices, VertexCount, Y0, Y1, Time0, Time1,
    DisplayTime, TimeAxisLength, BaseX, TopHeight, Color);
end;

procedure ResolvePitchBounds(ObjectHeight, Key, LowestKey, HighestKey: Integer;
  const Settings: TPianoRollDisplaySettings; NoteThickness: Double;
  out Y0, Y1: Double);
var
  Axis0, Axis1: Integer;
begin
  GetPianoRollNoteAxisBounds(ObjectHeight, Key, LowestKey, HighestKey,
    Settings.KeyboardType, Settings.KeyThickness, NoteThickness, True,
    Axis0, Axis1);
  Y0 := Axis0 - ObjectHeight * 0.5;
  Y1 := Axis1 - ObjectHeight * 0.5;
end;

procedure ResolveKeyboardBounds(ObjectHeight, Key, LowestKey,
  HighestKey: Integer; const Settings: TPianoRollDisplaySettings;
  out Y0, Y1: Double);
var
  Center, RangeCenter, Width: Double;
begin
  RangeCenter := (GetPianoKeyPitchCenter(LowestKey) +
    GetPianoKeyPitchCenter(HighestKey)) * 0.5;
  // 横表示は高音ほど画面上側、すなわち負のYへ配置する。
  Center := -(GetPianoKeyPitchCenter(Key) - RangeCenter) *
    Settings.KeyThickness;
  if (Settings.KeyboardType = pktHarp7) or not IsPianoBlackKey(Key) then
    Width := Settings.KeyThickness
  else
    Width := Settings.KeyThickness * 0.62;
  Y0 := Center - Width * 0.5;
  Y1 := Center + Width * 0.5;
end;

procedure AppendConnectedWhiteKeyboard(var Vertices: TVertexColorArray;
  var VertexCount: Integer; ObjectHeight, LowestKey, HighestKey: Integer;
  FrontTime, DisplayTime, TimeAxisLength, BaseX: Double;
  const Settings: TPianoRollDisplaySettings);
var
  BaseHeight: Double;
  EndColor, SideColor: TPianoRollColor;
  HasWhiteKey: Boolean;
  Key: Integer;
  OuterY0, OuterY1, TopHeight, Y0, Y1: Double;
begin
  HasWhiteKey := False;
  OuterY0 := MaxDouble;
  OuterY1 := -MaxDouble;
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      not IsPianoBlackKey(Key) then
    begin
      ResolveKeyboardBounds(ObjectHeight, Key, LowestKey, HighestKey,
        Settings, Y0, Y1);
      OuterY0 := Min(OuterY0, Y0);
      OuterY1 := Max(OuterY1, Y1);
      HasWhiteKey := True;
    end;
  if not HasWhiteKey then
    Exit;

  TopHeight := 4.0;
  BaseHeight := TopHeight - Max(0.0, Settings.WhiteKey3DThickness);
  if Settings.WhiteKey3DThickness > 0.0 then
  begin
    SideColor := ShadeColor(Settings.Palette.WhiteKey, 0.62);
    EndColor := ShadeColor(Settings.Palette.WhiteKey, 0.48);
    // 白鍵同士の共有境界を作らず、鍵盤全体の上下外周と左端だけを押し出す。
    AppendHeightQuad(Vertices, VertexCount, OuterY0, OuterY0,
      FrontTime, 0.0, BaseHeight, TopHeight, DisplayTime, TimeAxisLength,
      BaseX, SideColor);
    AppendHeightQuad(Vertices, VertexCount, OuterY1, OuterY1,
      0.0, FrontTime, BaseHeight, TopHeight, DisplayTime, TimeAxisLength,
      BaseX, SideColor);
    AppendHeightQuad(Vertices, VertexCount, OuterY1, OuterY0,
      FrontTime, FrontTime, BaseHeight, TopHeight, DisplayTime, TimeAxisLength,
      BaseX, EndColor);
  end;

  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      not IsPianoBlackKey(Key) then
    begin
      ResolveKeyboardBounds(ObjectHeight, Key, LowestKey, HighestKey,
        Settings, Y0, Y1);
      AppendPlaneQuadAtHeight(Vertices, VertexCount, Y0, Y1,
        FrontTime, 0.0, DisplayTime, TimeAxisLength, BaseX, TopHeight,
        Settings.Palette.WhiteKey);
    end;
end;

function GetNoteEndSeconds(const Note: TPianoRollNoteData): Double;
begin
  Result := Note.EndSeconds;
  if Result < Note.StartSeconds then
    Result := Note.StartSeconds + 0.2;
end;

function DrawHorizontalPianoRoll3D(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings): Boolean;
var
  BaseX, BeatHalfWidth, DisplayTime, FutureTime, TimeAxisLength: Double;
  EndSeconds, Time0, Time1, Y0, Y1: Double;
  Beat: TPianoRollBeatData;
  Color: TPianoRollColor;
  Height, HighestKey, I, Key, LowestKey: Integer;
  MaxMusicKey, MaxTrack, MinMusicKey, MinTrack: Integer;
  Note: TPianoRollNoteData;
  Vertices: TVertexColorArray;
  VertexCount, Width: Integer;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or
    not Assigned(Video^.DrawPoly) or not Assigned(Data) then
    Exit;
  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) then
    Exit;

  DisplayTime := Max(0.1, Settings.DisplayTime);
  FutureTime := Max(0.1, Settings.DisplayTime3D);
  TimeSeconds := TimeSeconds - Settings.TimeShift;
  ResolveEffectivePianoRollPitchRange(Data, TimeSeconds, FutureTime,
    Settings.CenterNote, Settings.VisibleNoteCount, Settings.PitchFollowMode,
    Settings.KeyboardType, LowestKey, HighestKey);
  GetPianoRollNoteRanges(Data, MinTrack, MaxTrack, MinMusicKey, MaxMusicKey);

  BaseX := Width * (0.5 - EnsureRange(Settings.StrikePosition, 0.0, 1.0));
  TimeAxisLength := Max(1.0,
    Width * EnsureRange(Settings.StrikePosition, 0.0, 1.0));
  VertexCount := 0;
  SetLength(Vertices, 1024);

  if Settings.ShowLanes then
    for Key := LowestKey to HighestKey do
    begin
      if not IsPianoRollKeyVisible(Key, Settings.KeyboardType) then
        Continue;
      ResolvePitchBounds(Height, Key, LowestKey, HighestKey, Settings,
        1.0, Y0, Y1);
      if IsPianoBlackKey(Key) then
        Color := Settings.Palette.BlackLane
      else
        Color := Settings.Palette.WhiteLane;
      AppendPlaneQuadAtHeight(Vertices, VertexCount, Y0, Y1, 0.0, FutureTime,
        DisplayTime, TimeAxisLength, BaseX, 0.0, Color);
    end;

  if Settings.ShowBeatLines then
  begin
    BeatHalfWidth := DisplayTime *
      ScalePianoRollThickness(1, Settings.KeyThickness) /
      TimeAxisLength * 0.5;
    for I := 0 to Data.BeatCount - 1 do
    begin
      Beat := Data.Beats[I];
      Time0 := Beat.Seconds - TimeSeconds;
      if (Time0 < 0.0) or (Time0 > FutureTime) then
        Continue;
      if (Beat.Index mod Max(1, Settings.BeatsPerMeasure)) = 0 then
        Color := Settings.Palette.MeasureLine
      else
        Color := Settings.Palette.BeatLine;
      AppendPlaneQuadAtHeight(Vertices, VertexCount, -Height * 0.5,
        Height * 0.5, Max(0.0, Time0 - BeatHalfWidth),
        Min(FutureTime, Time0 + BeatHalfWidth), DisplayTime, TimeAxisLength,
        BaseX, 1.0, Color);
    end;
  end;

  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if (Note.Key < LowestKey) or (Note.Key > HighestKey) or
      not IsPianoRollKeyVisible(Note.Key, Settings.KeyboardType) then
      Continue;
    EndSeconds := GetNoteEndSeconds(Note);
    Time0 := Max(0.0, Note.StartSeconds - TimeSeconds);
    Time1 := Min(FutureTime, EndSeconds - TimeSeconds);
    if Time1 <= Time0 then
      Continue;
    ResolvePitchBounds(Height, Note.Key, LowestKey, HighestKey, Settings,
      Settings.NoteThickness, Y0, Y1);
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey, Settings.TrackColorMode,
      Settings.SingleTrackColor, Settings.GradientColor1,
      Settings.GradientColor2, Settings.Palette);
    AppendExtrudedBox(Vertices, VertexCount, Y0, Y1, Time0, Time1,
      DisplayTime, TimeAxisLength, BaseX, 2.0,
      Settings.Note3DThickness, False, Color);
  end;

  BeatHalfWidth := DisplayTime *
    ScalePianoRollThickness(2, Settings.KeyThickness) / TimeAxisLength;
  AppendPlaneQuadAtHeight(Vertices, VertexCount, -Height * 0.5, Height * 0.5,
    0.0, Min(FutureTime, BeatHalfWidth), DisplayTime, TimeAxisLength,
    BaseX, 3.0, Settings.Palette.StrikeLine);

  // 横表示の鍵盤は発音線から左へ伸ばし、黒鍵を白鍵の左側へ寄せる。
  Time1 := -Settings.KeyLength / TimeAxisLength * DisplayTime;
  AppendConnectedWhiteKeyboard(Vertices, VertexCount, Height,
    LowestKey, HighestKey, Time1, DisplayTime, TimeAxisLength, BaseX,
    Settings);
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      IsPianoBlackKey(Key) then
    begin
      ResolveKeyboardBounds(Height, Key, LowestKey, HighestKey, Settings,
        Y0, Y1);
      AppendExtrudedBox(Vertices, VertexCount, Y0, Y1, Time1,
        Time1 * 0.38, DisplayTime, TimeAxisLength, BaseX, 4.0,
        Settings.BlackKey3DThickness, True, Settings.Palette.BlackKey);
    end;

  if VertexCount > 0 then
    Result := Video^.DrawPoly(VERTEX_QUAD_COLOR, @Vertices[0],
      VertexCount, nil) <> 0
  else
    Result := True;
  if Result and Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(Width, Height);
end;

end.

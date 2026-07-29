unit SYNC_PianoRoll_Perspective3DDisplay;

// 音階×時間の平面をXYZ頂点として構築し、AviUtl2へ直接描画する。

interface

uses
  AviUtl2FilterTypes,
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_MusicData;

function DrawPerspectivePianoRoll3D(Video: PFILTER_PROC_VIDEO;
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

procedure ResolvePlanePoint(TimeOffset, DisplayTime, TimeAxisLength, BaseY,
  Height: Double; out Y, Z: Single);
var
  TimePosition: Double;
begin
  TimePosition := TimeOffset / DisplayTime * TimeAxisLength;
  // 初期状態は2Dと同じX-Y平面。視点変更と厚みだけがZ座標を使用する。
  Y := BaseY - TimePosition;
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
  var VertexCount: Integer; X0, X1, Time0, Time1, DisplayTime,
  TimeAxisLength, BaseY, Height: Double;
  const Color: TPianoRollColor);
var
  RequiredCount: Integer;
  Y0, Y1, Z0, Z1: Single;
begin
  if (VertexCount div 4 >= MAX_QUAD_COUNT) or
    (X1 <= X0) or (Time1 <= Time0) then
    Exit;
  RequiredCount := VertexCount + 4;
  EnsureVertexCapacity(Vertices, RequiredCount);

  ResolvePlanePoint(Time0, DisplayTime, TimeAxisLength, BaseY,
    Height, Y0, Z0);
  ResolvePlanePoint(Time1, DisplayTime, TimeAxisLength, BaseY,
    Height, Y1, Z1);
  SetVertex(Vertices[VertexCount], X0, Y0, Z0, Color);
  SetVertex(Vertices[VertexCount + 1], X0, Y1, Z1, Color);
  SetVertex(Vertices[VertexCount + 2], X1, Y1, Z1, Color);
  SetVertex(Vertices[VertexCount + 3], X1, Y0, Z0, Color);
  Inc(VertexCount, 4);
end;

procedure AppendVerticalQuad(var Vertices: TVertexColorArray;
  var VertexCount: Integer; X0, X1, Time0, Time1, Height0, Height1,
  DisplayTime, TimeAxisLength, BaseY: Double; const Color: TPianoRollColor);
var
  Y00, Y01, Y10, Y11, Z00, Z01, Z10, Z11: Single;
begin
  if (VertexCount div 4 >= MAX_QUAD_COUNT) then
    Exit;
  EnsureVertexCapacity(Vertices, VertexCount + 4);
  ResolvePlanePoint(Time0, DisplayTime, TimeAxisLength, BaseY,
    Height0, Y00, Z00);
  ResolvePlanePoint(Time1, DisplayTime, TimeAxisLength, BaseY,
    Height0, Y01, Z01);
  ResolvePlanePoint(Time1, DisplayTime, TimeAxisLength, BaseY,
    Height1, Y11, Z11);
  ResolvePlanePoint(Time0, DisplayTime, TimeAxisLength, BaseY,
    Height1, Y10, Z10);
  SetVertex(Vertices[VertexCount], X0, Y00, Z00, Color);
  SetVertex(Vertices[VertexCount + 1], X1, Y01, Z01, Color);
  SetVertex(Vertices[VertexCount + 2], X1, Y11, Z11, Color);
  SetVertex(Vertices[VertexCount + 3], X0, Y10, Z10, Color);
  Inc(VertexCount, 4);
end;

procedure AppendExtrudedBox(var Vertices: TVertexColorArray;
  var VertexCount: Integer; X0, X1, Time0, Time1, DisplayTime,
  TimeAxisLength, BaseY, SurfaceHeight, Thickness: Double;
  GrowTowardViewer: Boolean;
  const Color: TPianoRollColor);
var
  BaseHeight: Double;
  SideColor, EndColor: TPianoRollColor;
  TopHeight: Double;
begin
  if (X1 <= X0) or (Time1 <= Time0) then
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
    AppendPlaneQuadAtHeight(Vertices, VertexCount, X0, X1, Time0, Time1,
      DisplayTime, TimeAxisLength, BaseY, TopHeight, Color);
    Exit;
  end;

  SideColor := ShadeColor(Color, 0.62);
  EndColor := ShadeColor(Color, 0.48);
  // 奥側端面は視点によって上面へ重なって見えるため生成しない。
  // 側面を先に、上面を最後に描き、上面が常に形状の表面として残るようにする。
  AppendVerticalQuad(Vertices, VertexCount, X0, X0, Time0, Time1,
    BaseHeight, TopHeight, DisplayTime, TimeAxisLength, BaseY, SideColor);
  AppendVerticalQuad(Vertices, VertexCount, X1, X1, Time1, Time0,
    BaseHeight, TopHeight, DisplayTime, TimeAxisLength, BaseY, SideColor);
  AppendVerticalQuad(Vertices, VertexCount, X0, X1, Time0, Time0,
    BaseHeight, TopHeight, DisplayTime, TimeAxisLength, BaseY, EndColor);
  AppendPlaneQuadAtHeight(Vertices, VertexCount, X0, X1, Time0, Time1,
    DisplayTime, TimeAxisLength, BaseY, TopHeight, Color);
end;

procedure ResolvePitchBounds(ObjectWidth, Key, LowestKey, HighestKey: Integer;
  const Settings: TPianoRollDisplaySettings; NoteThickness: Double;
  out X0, X1: Double);
var
  Axis0, Axis1: Integer;
begin
  GetPianoRollNoteAxisBounds(ObjectWidth, Key, LowestKey, HighestKey,
    Settings.KeyboardType, Settings.KeyThickness, NoteThickness, False,
    Axis0, Axis1);
  X0 := Axis0 - ObjectWidth * 0.5;
  X1 := Axis1 - ObjectWidth * 0.5;
end;

procedure ResolveKeyboardBounds(ObjectWidth, Key, LowestKey,
  HighestKey: Integer; const Settings: TPianoRollDisplaySettings;
  out X0, X1: Double);
var
  Center, RangeCenter, Width: Double;
begin
  RangeCenter := (GetPianoKeyPitchCenter(LowestKey) +
    GetPianoKeyPitchCenter(HighestKey)) * 0.5;
  Center := (GetPianoKeyPitchCenter(Key) - RangeCenter) *
    Settings.KeyThickness;
  if (Settings.KeyboardType = pktHarp7) or not IsPianoBlackKey(Key) then
    Width := Settings.KeyThickness
  else
    Width := Settings.KeyThickness * 0.62;
  X0 := Center - Width * 0.5;
  X1 := Center + Width * 0.5;
end;

procedure AppendConnectedWhiteKeyboard(var Vertices: TVertexColorArray;
  var VertexCount: Integer; ObjectWidth, LowestKey, HighestKey: Integer;
  FrontTime, DisplayTime, TimeAxisLength, BaseY: Double;
  const Settings: TPianoRollDisplaySettings);
var
  BaseHeight: Double;
  EndColor, SideColor: TPianoRollColor;
  HasWhiteKey: Boolean;
  Key: Integer;
  OuterX0, OuterX1, TopHeight, X0, X1: Double;
begin
  HasWhiteKey := False;
  OuterX0 := MaxDouble;
  OuterX1 := -MaxDouble;
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      not IsPianoBlackKey(Key) then
    begin
      ResolveKeyboardBounds(ObjectWidth, Key, LowestKey, HighestKey,
        Settings, X0, X1);
      OuterX0 := Min(OuterX0, X0);
      OuterX1 := Max(OuterX1, X1);
      HasWhiteKey := True;
    end;
  if not HasWhiteKey then
    Exit;

  // 白鍵上面を固定し、厚みは背面Zへ伸ばす。
  TopHeight := 4.0;
  BaseHeight := TopHeight - Max(0.0, Settings.WhiteKey3DThickness);
  if Settings.WhiteKey3DThickness > 0.0 then
  begin
    SideColor := ShadeColor(Settings.Palette.WhiteKey, 0.62);
    EndColor := ShadeColor(Settings.Palette.WhiteKey, 0.48);
    // 隣接鍵の共有境界には側面を作らず、鍵盤全体の外周だけを押し出す。
    AppendVerticalQuad(Vertices, VertexCount, OuterX0, OuterX0,
      FrontTime, 0.0, BaseHeight, TopHeight, DisplayTime, TimeAxisLength,
      BaseY, SideColor);
    AppendVerticalQuad(Vertices, VertexCount, OuterX1, OuterX1,
      0.0, FrontTime, BaseHeight, TopHeight, DisplayTime, TimeAxisLength,
      BaseY, SideColor);
    AppendVerticalQuad(Vertices, VertexCount, OuterX0, OuterX1,
      FrontTime, FrontTime, BaseHeight, TopHeight, DisplayTime, TimeAxisLength,
      BaseY, EndColor);
  end;

  // 全側面の後に鍵ごとの上面を描き、境界線を保ちつつ重なりを防ぐ。
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      not IsPianoBlackKey(Key) then
    begin
      ResolveKeyboardBounds(ObjectWidth, Key, LowestKey, HighestKey,
        Settings, X0, X1);
      AppendPlaneQuadAtHeight(Vertices, VertexCount, X0, X1,
        FrontTime, 0.0, DisplayTime, TimeAxisLength, BaseY, TopHeight,
        Settings.Palette.WhiteKey);
    end;
end;

function GetNoteEndSeconds(const Note: TPianoRollNoteData): Double;
begin
  Result := Note.EndSeconds;
  if Result < Note.StartSeconds then
    Result := Note.StartSeconds + 0.2;
end;

function DrawPerspectivePianoRoll3D(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings): Boolean;
var
  BaseY, BeatHalfWidth, DisplayTime, FutureTime, TimeAxisLength: Double;
  EndSeconds, Time0, Time1, X0, X1: Double;
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

  BaseY := Height * (EnsureRange(Settings.StrikePosition, 0.0, 1.0) - 0.5);
  TimeAxisLength := Max(1.0,
    Height * EnsureRange(Settings.StrikePosition, 0.0, 1.0));
  VertexCount := 0;
  SetLength(Vertices, 1024);

  if Settings.ShowLanes then
    for Key := LowestKey to HighestKey do
    begin
      if not IsPianoRollKeyVisible(Key, Settings.KeyboardType) then
        Continue;
      ResolvePitchBounds(Width, Key, LowestKey, HighestKey, Settings,
        1.0, X0, X1);
      if IsPianoBlackKey(Key) then
        Color := Settings.Palette.BlackLane
      else
        Color := Settings.Palette.WhiteLane;
      AppendPlaneQuadAtHeight(Vertices, VertexCount, X0, X1, 0.0, FutureTime,
        DisplayTime, TimeAxisLength, BaseY, 0.0, Color);
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
      AppendPlaneQuadAtHeight(Vertices, VertexCount, -Width * 0.5, Width * 0.5,
        Max(0.0, Time0 - BeatHalfWidth),
        Min(FutureTime, Time0 + BeatHalfWidth), DisplayTime, TimeAxisLength,
        BaseY, 1.0, Color);
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
    ResolvePitchBounds(Width, Note.Key, LowestKey, HighestKey, Settings,
      Settings.NoteThickness, X0, X1);
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey, Settings.TrackColorMode,
      Settings.SingleTrackColor, Settings.GradientColor1,
      Settings.GradientColor2, Settings.Palette);
    AppendExtrudedBox(Vertices, VertexCount, X0, X1, Time0, Time1,
      DisplayTime, TimeAxisLength, BaseY, 2.0,
      Settings.Note3DThickness, False, Color);
  end;

  BeatHalfWidth := DisplayTime *
    ScalePianoRollThickness(2, Settings.KeyThickness) / TimeAxisLength;
  AppendPlaneQuadAtHeight(Vertices, VertexCount, -Width * 0.5, Width * 0.5,
    0.0, Min(FutureTime, BeatHalfWidth), DisplayTime, TimeAxisLength,
    BaseY, 3.0, Settings.Palette.StrikeLine);

  // 鍵盤は発音線から手前へ伸ばす。白鍵を先に、黒鍵を後から重ねる。
  Time1 := -Settings.KeyLength / TimeAxisLength * DisplayTime;
  AppendConnectedWhiteKeyboard(Vertices, VertexCount, Width,
    LowestKey, HighestKey, Time1, DisplayTime, TimeAxisLength, BaseY,
    Settings);
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      IsPianoBlackKey(Key) then
    begin
      ResolveKeyboardBounds(Width, Key, LowestKey, HighestKey, Settings,
        X0, X1);
      // 黒鍵は白鍵上へ短く重ね、白鍵上面を底として手前Zへ立ち上げる。
      AppendExtrudedBox(Vertices, VertexCount, X0, X1, Time1 * 0.62, 0.0,
        DisplayTime, TimeAxisLength, BaseY, 4.0,
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

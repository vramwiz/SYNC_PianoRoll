program SYNC_PianoRoll_Perspective3DTests;

// 縦横3Dの座標軸、過去側ノート、鍵盤の前後関係、押し出しを検証する。

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SYNC_PianoRoll_MusicData in 'Source\Common\Data\SYNC_PianoRoll_MusicData.pas',
  SYNC_PianoRoll_PianoKeys in 'Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas',
  SYNC_PianoRoll_Colors in 'Source\Common\Color\SYNC_PianoRoll_Colors.pas',
  SYNC_PianoRoll_RGBA in 'Source\Common\Render\SYNC_PianoRoll_RGBA.pas',
  SYNC_PianoRoll_DisplayTypes in 'Source\Common\Layout\SYNC_PianoRoll_DisplayTypes.pas',
  SYNC_PianoRoll_PitchFollow in 'Source\Common\Layout\SYNC_PianoRoll_PitchFollow.pas',
  SYNC_PianoRoll_Vertical3DDisplay in 'Source\Display\Vertical3D\SYNC_PianoRoll_Vertical3DDisplay.pas',
  SYNC_PianoRoll_Horizontal3DDisplay in 'Source\Display\Horizontal3D\SYNC_PianoRoll_Horizontal3DDisplay.pas';

type
  TMockMusicData = class(TInterfacedObject, IPianoRollMusicData)
  public
    function GetFileName: string;
    function GetLengthSeconds: Double;
    function GetNoteCount: Integer;
    function GetNote(Index: Integer): TPianoRollNoteData;
    function GetBeatCount: Integer;
    function GetBeat(Index: Integer): TPianoRollBeatData;
    function GetTrackCount: Integer;
    function GetTrack(Index: Integer): TPianoRollTrackData;
  end;
  TVertexArray = array[0..(MaxInt div SizeOf(TVERTEX_COLOR)) - 1] of
    TVERTEX_COLOR;
  PVertexArray = ^TVertexArray;

var
  AnchorHeight, AnchorWidth: Integer;
  CapturedBlackMaxX, CapturedBlackMinX: Single;
  CapturedBlackMaxY, CapturedBlackMinY: Single;
  CapturedBlackMaxZ, CapturedBlackMinZ: Single;
  CapturedNoteVertexCount: Integer;
  CapturedOpaqueNoteVertexCount: Integer;
  CapturedNoteMaxY: Single;
  CapturedNoteMinX: Single;
  CapturedNoteMinZ: Single;
  CapturedNoteXRange: Single;
  CapturedNoteYRange: Single;
  CapturedNoteZRange: Single;
  CapturedTranslucentVertexCount: Integer;
  CapturedTranslucentXYQuads, CapturedTranslucentXZQuads,
    CapturedTranslucentYZQuads: Integer;
  CapturedConnectorMaxX, CapturedConnectorMinX: Single;
  CapturedVertexCount, CapturedVertexType: Integer;
  FirstActiveKeyQuad, FirstWhiteKeyQuad, LastActiveKeyQuad,
    LastBlackKeyQuad, LastFlowingNoteQuad: Integer;
  CapturedWhiteTopMinXRange, CapturedWhiteTopMinYRange: Single;
  CapturedWhiteMaxX, CapturedWhiteMinX: Single;
  CapturedWhiteMaxY, CapturedWhiteMinY: Single;
  CapturedWhiteMaxZ, CapturedWhiteMinZ: Single;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function CapturePoly(VertexType: Integer; VertexList: Pointer;
  VertexNum: Integer; Resource: PWideChar): Byte; cdecl;
var
  I, J: Integer;
  IsActiveKeyQuad, IsBlackKeyQuad, IsConnectorQuad,
  IsFlowingNoteQuad, IsTranslucentQuad, IsWhiteKeyQuad: Boolean;
  MaxQuadX, MaxQuadY, MaxQuadZ, MinQuadX, MinQuadY, MinQuadZ: Single;
  MaxNoteX, MaxNoteY, MaxNoteZ, MinNoteX, MinNoteY, MinNoteZ: Single;
  Vertex: TVERTEX_COLOR;
begin
  CapturedVertexType := VertexType;
  CapturedVertexCount := VertexNum;
  CapturedNoteVertexCount := 0;
  CapturedOpaqueNoteVertexCount := 0;
  CapturedTranslucentVertexCount := 0;
  CapturedTranslucentXYQuads := 0;
  CapturedTranslucentXZQuads := 0;
  CapturedTranslucentYZQuads := 0;
  CapturedConnectorMinX := MaxSingle;
  CapturedConnectorMaxX := -MaxSingle;
  FirstActiveKeyQuad := -1;
  LastActiveKeyQuad := -1;
  LastBlackKeyQuad := -1;
  LastFlowingNoteQuad := -1;
  FirstWhiteKeyQuad := -1;
  CapturedWhiteTopMinXRange := MaxSingle;
  CapturedWhiteTopMinYRange := MaxSingle;
  MinNoteX := MaxSingle;
  MaxNoteX := -MaxSingle;
  MinNoteY := MaxSingle;
  MaxNoteY := -MaxSingle;
  MinNoteZ := MaxSingle;
  MaxNoteZ := -MaxSingle;
  CapturedWhiteMinY := MaxSingle;
  CapturedWhiteMaxY := -MaxSingle;
  CapturedWhiteMinX := MaxSingle;
  CapturedWhiteMaxX := -MaxSingle;
  CapturedBlackMinY := MaxSingle;
  CapturedBlackMaxY := -MaxSingle;
  CapturedBlackMinX := MaxSingle;
  CapturedBlackMaxX := -MaxSingle;
  CapturedWhiteMinZ := MaxSingle;
  CapturedWhiteMaxZ := -MaxSingle;
  CapturedBlackMinZ := MaxSingle;
  CapturedBlackMaxZ := -MaxSingle;
  for I := 0 to VertexNum - 1 do
  begin
    Vertex := PVertexArray(VertexList)^[I];
    if (Vertex.A > 0.0001) and (Vertex.A < 0.9999) then
      Inc(CapturedTranslucentVertexCount);
    if (Abs(Vertex.R - 7 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 8 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 9 / 255.0) < 0.0001) then
    begin
      Inc(CapturedNoteVertexCount);
      if Vertex.A >= 0.9999 then
        Inc(CapturedOpaqueNoteVertexCount);
      MinNoteX := Min(MinNoteX, Vertex.X);
      MaxNoteX := Max(MaxNoteX, Vertex.X);
      MinNoteY := Min(MinNoteY, Vertex.Y);
      MaxNoteY := Max(MaxNoteY, Vertex.Y);
      MinNoteZ := Min(MinNoteZ, Vertex.Z);
      MaxNoteZ := Max(MaxNoteZ, Vertex.Z);
    end;
    if (Abs(Vertex.R - 242 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 242 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 242 / 255.0) < 0.0001) then
    begin
      CapturedWhiteMinX := Min(CapturedWhiteMinX, Vertex.X);
      CapturedWhiteMaxX := Max(CapturedWhiteMaxX, Vertex.X);
      CapturedWhiteMinY := Min(CapturedWhiteMinY, Vertex.Y);
      CapturedWhiteMaxY := Max(CapturedWhiteMaxY, Vertex.Y);
      CapturedWhiteMinZ := Min(CapturedWhiteMinZ, Vertex.Z);
      CapturedWhiteMaxZ := Max(CapturedWhiteMaxZ, Vertex.Z);
    end;
    if (Abs(Vertex.R - 24 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 24 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 24 / 255.0) < 0.0001) then
    begin
      CapturedBlackMinX := Min(CapturedBlackMinX, Vertex.X);
      CapturedBlackMaxX := Max(CapturedBlackMaxX, Vertex.X);
      CapturedBlackMinY := Min(CapturedBlackMinY, Vertex.Y);
      CapturedBlackMaxY := Max(CapturedBlackMaxY, Vertex.Y);
      CapturedBlackMinZ := Min(CapturedBlackMinZ, Vertex.Z);
      CapturedBlackMaxZ := Max(CapturedBlackMaxZ, Vertex.Z);
    end;
  end;
  for I := 0 to VertexNum div 4 - 1 do
  begin
    IsActiveKeyQuad := True;
    IsBlackKeyQuad := True;
    IsConnectorQuad := True;
    IsFlowingNoteQuad := True;
    IsTranslucentQuad := False;
    IsWhiteKeyQuad := True;
    MinQuadX := MaxSingle;
    MaxQuadX := -MaxSingle;
    MinQuadY := MaxSingle;
    MaxQuadY := -MaxSingle;
    MinQuadZ := MaxSingle;
    MaxQuadZ := -MaxSingle;
    for J := 0 to 3 do
    begin
      Vertex := PVertexArray(VertexList)^[I * 4 + J];
      IsTranslucentQuad := IsTranslucentQuad or
        ((Vertex.A > 0.0001) and (Vertex.A < 0.9999));
      MinQuadX := Min(MinQuadX, Vertex.X);
      MaxQuadX := Max(MaxQuadX, Vertex.X);
      MinQuadY := Min(MinQuadY, Vertex.Y);
      MaxQuadY := Max(MaxQuadY, Vertex.Y);
      MinQuadZ := Min(MinQuadZ, Vertex.Z);
      MaxQuadZ := Max(MaxQuadZ, Vertex.Z);
      IsActiveKeyQuad := IsActiveKeyQuad and
        (Abs(Vertex.R - 7 / 255.0) < 0.0001) and
        (Abs(Vertex.G - 8 / 255.0) < 0.0001) and
        (Abs(Vertex.B - 9 / 255.0) < 0.0001) and
        (Vertex.A >= 0.9999) and (Abs(Vertex.Z + 4.0) < 0.001);
      IsBlackKeyQuad := IsBlackKeyQuad and
        (Abs(Vertex.R - 24 / 255.0) < 0.0001) and
        (Abs(Vertex.G - 24 / 255.0) < 0.0001) and
        (Abs(Vertex.B - 24 / 255.0) < 0.0001) and
        (Vertex.A >= 0.9999) and (Abs(Vertex.Z + 4.0) < 0.001);
      IsWhiteKeyQuad := IsWhiteKeyQuad and
        (Abs(Vertex.R - 242 / 255.0) < 0.0001) and
        (Abs(Vertex.G - 242 / 255.0) < 0.0001) and
        (Abs(Vertex.B - 242 / 255.0) < 0.0001) and
        (Vertex.A >= 0.9999) and (Abs(Vertex.Z + 4.0) < 0.001);
      IsConnectorQuad := IsConnectorQuad and
        (Abs(Vertex.A - 140 / 255.0) < 0.0001);
      IsFlowingNoteQuad := IsFlowingNoteQuad and
        (Abs(Vertex.R - 7 / 255.0) < 0.0001) and
        (Abs(Vertex.G - 8 / 255.0) < 0.0001) and
        (Abs(Vertex.B - 9 / 255.0) < 0.0001) and
        (Vertex.A >= 0.9999) and (Abs(Vertex.Z + 2.0) < 0.001);
    end;
    if IsActiveKeyQuad then
    begin
      if FirstActiveKeyQuad < 0 then
        FirstActiveKeyQuad := I;
      LastActiveKeyQuad := I;
    end;
    if IsBlackKeyQuad then
      LastBlackKeyQuad := I;
    if IsFlowingNoteQuad then
      LastFlowingNoteQuad := I;
    if IsWhiteKeyQuad then
    begin
      if FirstWhiteKeyQuad < 0 then
        FirstWhiteKeyQuad := I;
      CapturedWhiteTopMinXRange := Min(CapturedWhiteTopMinXRange,
        MaxQuadX - MinQuadX);
      CapturedWhiteTopMinYRange := Min(CapturedWhiteTopMinYRange,
        MaxQuadY - MinQuadY);
    end;
    if IsConnectorQuad and (MaxQuadX - MinQuadX < 0.001) and
      (MaxQuadZ - MinQuadZ > 1.0) then
    begin
      CapturedConnectorMinX := Min(CapturedConnectorMinX, MinQuadX);
      CapturedConnectorMaxX := Max(CapturedConnectorMaxX, MaxQuadX);
    end;
    if IsTranslucentQuad then
    begin
      if (MaxQuadX - MinQuadX > 0.1) and
        (MaxQuadY - MinQuadY > 0.1) and
        (MaxQuadZ - MinQuadZ < 0.001) then
        Inc(CapturedTranslucentXYQuads);
      if (MaxQuadX - MinQuadX > 0.1) and
        (MaxQuadZ - MinQuadZ > 0.1) and
        (MaxQuadY - MinQuadY < 0.001) then
        Inc(CapturedTranslucentXZQuads);
      if (MaxQuadY - MinQuadY > 0.1) and
        (MaxQuadZ - MinQuadZ > 0.1) and
        (MaxQuadX - MinQuadX < 0.001) then
        Inc(CapturedTranslucentYZQuads);
    end;
  end;
  CapturedNoteXRange := MaxNoteX - MinNoteX;
  CapturedNoteYRange := MaxNoteY - MinNoteY;
  CapturedNoteZRange := MaxNoteZ - MinNoteZ;
  CapturedNoteMinX := MinNoteX;
  CapturedNoteMaxY := MaxNoteY;
  CapturedNoteMinZ := MinNoteZ;
  Result := 1;
end;

procedure CaptureAnchor(Width, Height: Integer); cdecl;
begin
  AnchorWidth := Width;
  AnchorHeight := Height;
end;

function TMockMusicData.GetFileName: string;
begin
  Result := 'mock.mid';
end;

function TMockMusicData.GetLengthSeconds: Double;
begin
  Result := 12.0;
end;

function TMockMusicData.GetNoteCount: Integer;
begin
  Result := 3;
end;

function TMockMusicData.GetNote(Index: Integer): TPianoRollNoteData;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Index = 2 then
  begin
    Result.StartSeconds := 10.0;
    Result.EndSeconds := 11.0;
  end
  else
  begin
    Result.StartSeconds := 0.5;
    Result.EndSeconds := 1.5;
  end;
  Result.Key := 60 + Index;
  Result.Velocity := 100;
  Result.TrackIndex := 0;
end;

function TMockMusicData.GetBeatCount: Integer;
begin
  Result := 0;
end;

function TMockMusicData.GetBeat(Index: Integer): TPianoRollBeatData;
begin
  raise ERangeError.Create('beat index');
end;

function TMockMusicData.GetTrackCount: Integer;
begin
  Result := 0;
end;

function TMockMusicData.GetTrack(Index: Integer): TPianoRollTrackData;
begin
  raise ERangeError.Create('track index');
end;

var
  BaselineBlackTopZ, BaselineNoteMinZ, BaselineWhiteTopZ: Single;
  Data: IPianoRollMusicData;
  HorizontalBaseTranslucentVertexCount: Integer;
  BaseTranslucentXYQuads, BaseTranslucentXZQuads,
    BaseTranslucentYZQuads: Integer;
  HorizontalBlackTopZ, HorizontalWhiteTopZ: Single;
  HorizontalStandardVertexCount, HorizontalWhiteThicknessVertexCount: Integer;
  ObjectInfo: TOBJECT_INFO;
  Settings: TPianoRollDisplaySettings;
  StandardVertexCount: Integer;
  VerticalBaseTranslucentVertexCount: Integer;
  WhiteThicknessVertexCount: Integer;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := 640;
  ObjectInfo.Height := 360;
  Video.Object_ := @ObjectInfo;
  Video.DrawPoly := CapturePoly;
  Video.SetDefaultAnchor := CaptureAnchor;
  Data := TMockMusicData.Create;
  SetDefaultPianoRollDisplaySettings(Settings);
  Settings.ShowLanes := False;
  Settings.ShowBeatLines := False;
  Settings.CenterNote := 60;
  Settings.VisibleNoteCount := 12;
  Settings.SingleTrackColor := PianoRollColor(7, 8, 9, 255);
  Settings.DisplayTime3D := 4.0;

  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'vertical 3D draw failed');
  Check(CapturedVertexType = VERTEX_QUAD_COLOR, 'vertex type mismatch');
  Check((CapturedVertexCount mod 4) = 0, 'quad vertex count mismatch');
  Check(CapturedNoteVertexCount = 8, 'standard notes were not drawn');
  Check(CapturedNoteYRange > 1.0, 'time axis is not on the screen plane');
  Check(CapturedNoteZRange < 0.001, 'flat note has unintended Z depth');
  Check((CapturedBlackMinY >= CapturedWhiteMinY - 0.001) and
    (CapturedBlackMaxY < CapturedWhiteMaxY),
    'black keys are not overlaid within the white key Y range');
  Check(CapturedWhiteMaxY > CapturedWhiteMinY,
    'white keys do not extend below the strike Y');
  Check(CapturedBlackMaxY > CapturedBlackMinY,
    'black keys have no length');
  Check(Abs(CapturedWhiteTopMinXRange - 38.0) < 0.001,
    'vertical white key gap is not size-scaled');
  Check(Abs(CapturedWhiteMinZ - CapturedBlackMinZ) < 0.001,
    'flat white and black key surfaces are separated');
  Check((AnchorWidth = 640) and (AnchorHeight = 360),
    'default anchor mismatch');
  StandardVertexCount := CapturedVertexCount;
  BaselineWhiteTopZ := CapturedWhiteMinZ;
  BaselineBlackTopZ := CapturedBlackMinZ;
  BaselineNoteMinZ := CapturedNoteMinZ;

  Settings.NotePositionOffset := 10.0;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'positive vertical note position offset draw failed');
  Check(CapturedNoteMinZ < BaselineNoteMinZ - 9.0,
    'positive vertical note position offset did not move notes forward');
  Check(DrawHorizontalPianoRoll3D(@Video, Data, 0.0, Settings),
    'positive horizontal note position offset draw failed');
  Check(CapturedNoteMinZ < BaselineNoteMinZ - 9.0,
    'positive horizontal note position offset did not move notes forward');
  Settings.NotePositionOffset := -10.0;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'negative vertical note position offset draw failed');
  Check(CapturedNoteMinZ > BaselineNoteMinZ + 9.0,
    'negative vertical note position offset did not move notes backward');
  Settings.NotePositionOffset := 0.0;

  // 中央へ移した鍵盤の過去側にもノートを生成し、鍵盤を手前のZと描画順へ置く。
  Settings.StrikePosition := 0.50;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 4.0, Settings),
    'centered vertical past-note draw failed');
  Check(CapturedNoteVertexCount = 8,
    'vertical past notes disappeared at the keyboard');
  Check((LastFlowingNoteQuad >= 0) and
    (LastFlowingNoteQuad < FirstWhiteKeyQuad) and
    (CapturedWhiteMinZ < CapturedNoteMinZ - 1.0),
    'vertical keyboard was not placed in front of notes');
  Check(CapturedNoteMaxY > CapturedWhiteMaxY + 1.0,
    'vertical past notes did not emerge beyond the keyboard');
  Check(DrawHorizontalPianoRoll3D(@Video, Data, 4.0, Settings),
    'centered horizontal past-note draw failed');
  Check(CapturedNoteVertexCount = 8,
    'horizontal past notes disappeared at the keyboard');
  Check((LastFlowingNoteQuad >= 0) and
    (LastFlowingNoteQuad < FirstWhiteKeyQuad) and
    (CapturedWhiteMinZ < CapturedNoteMinZ - 1.0),
    'horizontal keyboard was not placed in front of notes');
  Check(CapturedNoteMinX < CapturedWhiteMinX - 1.0,
    'horizontal past notes did not emerge beyond the keyboard');
  Settings.StrikePosition := 0.80;

  Settings.DisplayTime3D := 30.0;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'extended 3D time draw failed');
  Check(CapturedNoteVertexCount = 12,
    '3D display time did not include the distant future note');
  Check(CapturedVertexCount = StandardVertexCount + 4,
    'extended 3D time note quad count mismatch');
  Settings.DisplayTime3D := 4.0;

  Settings.WhiteKey3DThickness := 10;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'white key extrusion failed');
  Check(CapturedVertexCount = StandardVertexCount + 2 * 4,
    'connected white keyboard end faces mismatch');
  Check((Abs(CapturedWhiteMinZ - BaselineWhiteTopZ) < 0.001) and
    (Abs(CapturedBlackMinZ - BaselineBlackTopZ) < 0.001),
    'white thickness moved the white or black top surface');
  WhiteThicknessVertexCount := CapturedVertexCount;

  Settings.BlackKey3DThickness := 20;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'black key extrusion failed');
  Check(CapturedVertexCount = WhiteThicknessVertexCount + 5 * 16,
    'black key side faces mismatch');
  Check((Abs(CapturedWhiteMinZ - BaselineWhiteTopZ) < 0.001) and
    (CapturedBlackMinZ < BaselineBlackTopZ - 1.0),
    'black thickness did not rise from the white top surface');

  Settings.Note3DThickness := 30;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'note extrusion failed');
  Check(CapturedVertexCount =
    WhiteThicknessVertexCount + 5 * 16 + 2 * 16,
    'note side faces mismatch');

  Settings.WhiteKey3DThickness := 0;
  Settings.BlackKey3DThickness := 0;
  Settings.Note3DThickness := 0;
  Settings.KeyboardType := pktHarp7;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'harp 3D draw failed');
  Check(CapturedNoteVertexCount = 4, 'harp accidental was not hidden');
  Check(CapturedVertexCount < StandardVertexCount,
    'harp keyboard and note geometry were not reduced');

  Settings.KeyboardType := pktPiano;
  Check(DrawHorizontalPianoRoll3D(@Video, Data, 0.0, Settings),
    'horizontal 3D draw failed');
  Check(CapturedNoteXRange > 1.0,
    'horizontal 3D time axis is not on X');
  Check(CapturedNoteYRange > 1.0,
    'horizontal 3D pitch axis is not on Y');
  Check(CapturedNoteZRange < 0.001,
    'horizontal flat note has unintended Z depth');
  Check((CapturedBlackMinX >= CapturedWhiteMinX - 0.001) and
    (CapturedBlackMaxX < CapturedWhiteMaxX),
    'horizontal black keys are not placed within the white key X range');
  Check(Abs(CapturedWhiteTopMinYRange - 38.0) < 0.001,
    'horizontal white key gap is not size-scaled');
  HorizontalStandardVertexCount := CapturedVertexCount;
  HorizontalWhiteTopZ := CapturedWhiteMinZ;
  HorizontalBlackTopZ := CapturedBlackMinZ;

  Settings.WhiteKey3DThickness := 10;
  Check(DrawHorizontalPianoRoll3D(@Video, Data, 0.0, Settings),
    'horizontal white key extrusion failed');
  Check(CapturedVertexCount = HorizontalStandardVertexCount + 2 * 4,
    'horizontal connected white keyboard end faces mismatch');
  Check((Abs(CapturedWhiteMinZ - HorizontalWhiteTopZ) < 0.001) and
    (Abs(CapturedBlackMinZ - HorizontalBlackTopZ) < 0.001),
    'horizontal white thickness moved a key top surface');
  HorizontalWhiteThicknessVertexCount := CapturedVertexCount;

  Settings.BlackKey3DThickness := 20;
  Check(DrawHorizontalPianoRoll3D(@Video, Data, 0.0, Settings),
    'horizontal black key extrusion failed');
  Check(CapturedVertexCount =
    HorizontalWhiteThicknessVertexCount + 5 * 16,
    'horizontal black key side faces mismatch');
  Check(CapturedBlackMinZ < HorizontalBlackTopZ - 1.0,
    'horizontal black thickness did not rise from the white top surface');

  Settings.Note3DThickness := 30;
  Check(DrawHorizontalPianoRoll3D(@Video, Data, 0.0, Settings),
    'horizontal note extrusion failed');
  Check(CapturedVertexCount =
    HorizontalWhiteThicknessVertexCount + 5 * 16 + 2 * 16,
    'horizontal note side faces mismatch');

  Settings.WhiteKey3DThickness := 0;
  Settings.BlackKey3DThickness := 0;
  Settings.Note3DThickness := 0;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.9, Settings),
    'vertical active key after glow draw failed');
  Check(CapturedOpaqueNoteVertexCount >= 16,
    'vertical active keys did not remain lit');
  Check((FirstActiveKeyQuad >= 0) and
    (FirstActiveKeyQuad < LastBlackKeyQuad) and
    (LastBlackKeyQuad < LastActiveKeyQuad),
    Format('vertical active white key order mismatch: %d, %d, %d',
      [FirstActiveKeyQuad, LastBlackKeyQuad, LastActiveKeyQuad]));
  VerticalBaseTranslucentVertexCount := CapturedTranslucentVertexCount;
  BaseTranslucentXYQuads := CapturedTranslucentXYQuads;
  BaseTranslucentXZQuads := CapturedTranslucentXZQuads;
  BaseTranslucentYZQuads := CapturedTranslucentYZQuads;
  Check(DrawVerticalPianoRoll3D(@Video, Data, 0.5, Settings),
    'vertical active key and glow draw failed');
  Check(CapturedOpaqueNoteVertexCount >= 16,
    'vertical active keys were not recolored');
  Check(CapturedTranslucentVertexCount >
    VerticalBaseTranslucentVertexCount,
    'vertical strike glow was not generated');
  Check((CapturedTranslucentXYQuads > BaseTranslucentXYQuads) and
    (CapturedTranslucentXZQuads > BaseTranslucentXZQuads) and
    (CapturedTranslucentYZQuads > BaseTranslucentYZQuads),
    'vertical strike glow did not generate three orthogonal planes');

  Check(DrawHorizontalPianoRoll3D(@Video, Data, 0.9, Settings),
    'horizontal active key after glow draw failed');
  Check(CapturedOpaqueNoteVertexCount >= 16,
    'horizontal active keys did not remain lit');
  Check((FirstActiveKeyQuad >= 0) and
    (FirstActiveKeyQuad < LastBlackKeyQuad) and
    (LastBlackKeyQuad < LastActiveKeyQuad),
    Format('horizontal active white key order mismatch: %d, %d, %d',
      [FirstActiveKeyQuad, LastBlackKeyQuad, LastActiveKeyQuad]));
  HorizontalBaseTranslucentVertexCount := CapturedTranslucentVertexCount;
  BaseTranslucentXYQuads := CapturedTranslucentXYQuads;
  BaseTranslucentXZQuads := CapturedTranslucentXZQuads;
  BaseTranslucentYZQuads := CapturedTranslucentYZQuads;
  Check(DrawHorizontalPianoRoll3D(@Video, Data, 0.5, Settings),
    'horizontal active key and glow draw failed');
  Check(CapturedOpaqueNoteVertexCount >= 16,
    'horizontal active keys were not recolored');
  Check(CapturedTranslucentVertexCount >
    HorizontalBaseTranslucentVertexCount,
    'horizontal strike glow was not generated');
  Check((CapturedTranslucentXYQuads > BaseTranslucentXYQuads) and
    (CapturedTranslucentXZQuads > BaseTranslucentXZQuads) and
    (CapturedTranslucentYZQuads > BaseTranslucentYZQuads),
    'horizontal strike glow did not generate three orthogonal planes');
  Check(CapturedConnectorMaxX - CapturedConnectorMinX >
    Settings.KeyLength * 0.35,
    'horizontal black key effect was not moved to the black key edge');

  Video.DrawPoly := nil;
  Check(not DrawVerticalPianoRoll3D(@Video, Data, 0.0, Settings),
    'vertical DrawPoly absence was not reported');
  Check(not DrawHorizontalPianoRoll3D(@Video, Data, 0.0, Settings),
    'DrawPoly absence was not reported');
  Writeln('PASS');
end.

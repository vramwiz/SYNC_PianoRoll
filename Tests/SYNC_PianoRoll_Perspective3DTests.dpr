program SYNC_PianoRoll_Perspective3DTests;

// 3D平面の頂点生成、ハープの半音除外、DrawPoly非対応時の判定を検証する。

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
  SYNC_PianoRoll_Perspective3DDisplay in 'Source\Display\Perspective3D\SYNC_PianoRoll_Perspective3DDisplay.pas';

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
  CapturedBlackMaxY, CapturedBlackMinY: Single;
  CapturedBlackMaxZ, CapturedBlackMinZ: Single;
  CapturedNoteVertexCount: Integer;
  CapturedNoteYRange: Single;
  CapturedNoteZRange: Single;
  CapturedVertexCount, CapturedVertexType: Integer;
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
  I: Integer;
  MaxNoteY, MaxNoteZ, MinNoteY, MinNoteZ: Single;
  Vertex: TVERTEX_COLOR;
begin
  CapturedVertexType := VertexType;
  CapturedVertexCount := VertexNum;
  CapturedNoteVertexCount := 0;
  MinNoteY := MaxSingle;
  MaxNoteY := -MaxSingle;
  MinNoteZ := MaxSingle;
  MaxNoteZ := -MaxSingle;
  CapturedWhiteMinY := MaxSingle;
  CapturedWhiteMaxY := -MaxSingle;
  CapturedBlackMinY := MaxSingle;
  CapturedBlackMaxY := -MaxSingle;
  CapturedWhiteMinZ := MaxSingle;
  CapturedWhiteMaxZ := -MaxSingle;
  CapturedBlackMinZ := MaxSingle;
  CapturedBlackMaxZ := -MaxSingle;
  for I := 0 to VertexNum - 1 do
  begin
    Vertex := PVertexArray(VertexList)^[I];
    if (Abs(Vertex.R - 7 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 8 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 9 / 255.0) < 0.0001) then
    begin
      Inc(CapturedNoteVertexCount);
      MinNoteY := Min(MinNoteY, Vertex.Y);
      MaxNoteY := Max(MaxNoteY, Vertex.Y);
      MinNoteZ := Min(MinNoteZ, Vertex.Z);
      MaxNoteZ := Max(MaxNoteZ, Vertex.Z);
    end;
    if (Abs(Vertex.R - 242 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 242 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 242 / 255.0) < 0.0001) then
    begin
      CapturedWhiteMinY := Min(CapturedWhiteMinY, Vertex.Y);
      CapturedWhiteMaxY := Max(CapturedWhiteMaxY, Vertex.Y);
      CapturedWhiteMinZ := Min(CapturedWhiteMinZ, Vertex.Z);
      CapturedWhiteMaxZ := Max(CapturedWhiteMaxZ, Vertex.Z);
    end;
    if (Abs(Vertex.R - 24 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 24 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 24 / 255.0) < 0.0001) then
    begin
      CapturedBlackMinY := Min(CapturedBlackMinY, Vertex.Y);
      CapturedBlackMaxY := Max(CapturedBlackMaxY, Vertex.Y);
      CapturedBlackMinZ := Min(CapturedBlackMinZ, Vertex.Z);
      CapturedBlackMaxZ := Max(CapturedBlackMaxZ, Vertex.Z);
    end;
  end;
  CapturedNoteYRange := MaxNoteY - MinNoteY;
  CapturedNoteZRange := MaxNoteZ - MinNoteZ;
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
  BaselineBlackTopZ, BaselineWhiteTopZ: Single;
  Data: IPianoRollMusicData;
  ObjectInfo: TOBJECT_INFO;
  Settings: TPianoRollDisplaySettings;
  StandardVertexCount: Integer;
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

  Check(DrawPerspectivePianoRoll3D(@Video, Data, 0.0, Settings),
    '3D draw failed');
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
  Check(Abs(CapturedWhiteMinZ - CapturedBlackMinZ) < 0.001,
    'flat white and black key surfaces are separated');
  Check((AnchorWidth = 640) and (AnchorHeight = 360),
    'default anchor mismatch');
  StandardVertexCount := CapturedVertexCount;
  BaselineWhiteTopZ := CapturedWhiteMinZ;
  BaselineBlackTopZ := CapturedBlackMinZ;

  Settings.DisplayTime3D := 30.0;
  Check(DrawPerspectivePianoRoll3D(@Video, Data, 0.0, Settings),
    'extended 3D time draw failed');
  Check(CapturedNoteVertexCount = 12,
    '3D display time did not include the distant future note');
  Check(CapturedVertexCount = StandardVertexCount + 4,
    'extended 3D time note quad count mismatch');
  Settings.DisplayTime3D := 4.0;

  Settings.WhiteKey3DThickness := 10;
  Check(DrawPerspectivePianoRoll3D(@Video, Data, 0.0, Settings),
    'white key extrusion failed');
  Check(CapturedVertexCount = StandardVertexCount + 3 * 4,
    'connected white keyboard outer faces mismatch');
  Check((Abs(CapturedWhiteMinZ - BaselineWhiteTopZ) < 0.001) and
    (Abs(CapturedBlackMinZ - BaselineBlackTopZ) < 0.001),
    'white thickness moved the white or black top surface');
  WhiteThicknessVertexCount := CapturedVertexCount;

  Settings.BlackKey3DThickness := 20;
  Check(DrawPerspectivePianoRoll3D(@Video, Data, 0.0, Settings),
    'black key extrusion failed');
  Check(CapturedVertexCount = WhiteThicknessVertexCount + 5 * 12,
    'black key side faces mismatch');
  Check((Abs(CapturedWhiteMinZ - BaselineWhiteTopZ) < 0.001) and
    (CapturedBlackMinZ < BaselineBlackTopZ - 1.0),
    'black thickness did not rise from the white top surface');

  Settings.Note3DThickness := 30;
  Check(DrawPerspectivePianoRoll3D(@Video, Data, 0.0, Settings),
    'note extrusion failed');
  Check(CapturedVertexCount =
    WhiteThicknessVertexCount + 5 * 12 + 2 * 12,
    'note side faces mismatch');

  Settings.WhiteKey3DThickness := 0;
  Settings.BlackKey3DThickness := 0;
  Settings.Note3DThickness := 0;
  Settings.KeyboardType := pktHarp7;
  Check(DrawPerspectivePianoRoll3D(@Video, Data, 0.0, Settings),
    'harp 3D draw failed');
  Check(CapturedNoteVertexCount = 4, 'harp accidental was not hidden');
  Check(CapturedVertexCount < StandardVertexCount,
    'harp keyboard and note geometry were not reduced');

  Video.DrawPoly := nil;
  Check(not DrawPerspectivePianoRoll3D(@Video, Data, 0.0, Settings),
    'DrawPoly absence was not reported');
  Writeln('PASS');
end.

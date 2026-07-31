program SYNC_PianoRoll_Circular3DTests;

// 3D Type2の自動半径、円環鍵盤、過去／未来ノート、描画順を検証する。

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
  SYNC_PianoRoll_Circular3DDisplay in 'Source\Display\Circular3D\SYNC_PianoRoll_Circular3DDisplay.pas';

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
  CapturedActiveBlackKeyVertices: Integer;
  CapturedActiveKeyVertices: Integer;
  CapturedActiveWhiteKeyVertices: Integer;
  CapturedBlackMaximumRadius, CapturedBlackMinimumRadius: Double;
  CapturedBlackLaneVertices: Integer;
  CapturedBlackSideMaximumZ, CapturedBlackSideMinimumZ: Single;
  CapturedBlackVertices: Integer;
  CapturedBeatLineVertices: Integer;
  CapturedGlowVertices: Integer;
  CapturedMaximumRadius: Double;
  CapturedMeasureLineVertices: Integer;
  CapturedNoteMaximumRadius, CapturedNoteMinimumRadius: Double;
  CapturedNoteMaximumZ, CapturedNoteMinimumZ: Single;
  CapturedNoteVertices: Integer;
  CapturedVertexCount: Integer;
  CapturedWhiteSideMaximumZ, CapturedWhiteSideMinimumZ: Single;
  CapturedWhiteSideVertices: Integer;
  CapturedWhiteLaneVertices: Integer;
  CapturedWhiteMaximumZ, CapturedWhiteMinimumZ: Single;
  CapturedWhiteVertices: Integer;
  FirstWhiteQuad, LastNoteQuad: Integer;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function CapturePoly(VertexType: Integer; VertexList: Pointer;
  VertexNum: Integer; Resource: PWideChar): Byte; cdecl;
var
  I, J: Integer;
  IsNoteQuad, IsWhiteQuad: Boolean;
  QuadMaximumRadius, QuadMaximumZ, QuadMinimumRadius, QuadMinimumZ: Double;
  Radius: Double;
  Vertex: TVERTEX_COLOR;
begin
  CapturedVertexCount := VertexNum;
  CapturedActiveBlackKeyVertices := 0;
  CapturedActiveKeyVertices := 0;
  CapturedActiveWhiteKeyVertices := 0;
  CapturedBlackMaximumRadius := 0.0;
  CapturedBlackMinimumRadius := MaxDouble;
  CapturedBlackLaneVertices := 0;
  CapturedBlackVertices := 0;
  CapturedBeatLineVertices := 0;
  CapturedBlackSideMaximumZ := -MaxSingle;
  CapturedBlackSideMinimumZ := MaxSingle;
  CapturedGlowVertices := 0;
  CapturedMaximumRadius := 0.0;
  CapturedMeasureLineVertices := 0;
  CapturedNoteMaximumZ := -MaxSingle;
  CapturedNoteMinimumZ := MaxSingle;
  CapturedNoteMaximumRadius := 0.0;
  CapturedNoteMinimumRadius := MaxDouble;
  CapturedNoteVertices := 0;
  CapturedWhiteSideMaximumZ := -MaxSingle;
  CapturedWhiteSideMinimumZ := MaxSingle;
  CapturedWhiteSideVertices := 0;
  CapturedWhiteLaneVertices := 0;
  CapturedWhiteMaximumZ := -MaxSingle;
  CapturedWhiteMinimumZ := MaxSingle;
  CapturedWhiteVertices := 0;
  FirstWhiteQuad := -1;
  LastNoteQuad := -1;
  for I := 0 to VertexNum - 1 do
  begin
    Vertex := PVertexArray(VertexList)^[I];
    Radius := Sqrt(Sqr(Vertex.X) + Sqr(Vertex.Y));
    CapturedMaximumRadius := Max(CapturedMaximumRadius, Radius);
    if (Vertex.A < 0.999) and
      (Abs(Vertex.A - 28 / 255.0) > 0.0001) and
      (Abs(Vertex.A - 24 / 255.0) > 0.0001) and
      (Abs(Vertex.A - 48 / 255.0) > 0.0001) and
      (Abs(Vertex.A - 120 / 255.0) > 0.0001) then
      Inc(CapturedGlowVertices);
    if (Abs(Vertex.R - 238 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 238 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 242 / 255.0) < 0.0001) and
      (Abs(Vertex.A - 28 / 255.0) < 0.0001) then
      Inc(CapturedWhiteLaneVertices);
    if (Abs(Vertex.R - 110 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 110 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 120 / 255.0) < 0.0001) and
      (Abs(Vertex.A - 24 / 255.0) < 0.0001) then
      Inc(CapturedBlackLaneVertices);
    if (Abs(Vertex.R - 1.0) < 0.0001) and
      (Abs(Vertex.G - 1.0) < 0.0001) and
      (Abs(Vertex.B - 1.0) < 0.0001) and
      (Abs(Vertex.A - 48 / 255.0) < 0.0001) then
      Inc(CapturedBeatLineVertices);
    if (Abs(Vertex.R - 1.0) < 0.0001) and
      (Abs(Vertex.G - 190 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 80 / 255.0) < 0.0001) and
      (Abs(Vertex.A - 120 / 255.0) < 0.0001) then
      Inc(CapturedMeasureLineVertices);
    if (Abs(Vertex.R - 242 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 242 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 242 / 255.0) < 0.0001) then
    begin
      Inc(CapturedWhiteVertices);
      CapturedWhiteMinimumZ := Min(CapturedWhiteMinimumZ, Vertex.Z);
      CapturedWhiteMaximumZ := Max(CapturedWhiteMaximumZ, Vertex.Z);
    end;
    if (Abs(Vertex.R - 24 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 24 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 24 / 255.0) < 0.0001) then
    begin
      Inc(CapturedBlackVertices);
      CapturedBlackMinimumRadius := Min(CapturedBlackMinimumRadius, Radius);
      CapturedBlackMaximumRadius := Max(CapturedBlackMaximumRadius, Radius);
    end;
    if (Abs(Vertex.R - 133 / 255.0) < 0.0001) and
      (Abs(Vertex.G - 133 / 255.0) < 0.0001) and
      (Abs(Vertex.B - 133 / 255.0) < 0.0001) then
    begin
      Inc(CapturedWhiteSideVertices);
      CapturedWhiteSideMinimumZ := Min(CapturedWhiteSideMinimumZ, Vertex.Z);
      CapturedWhiteSideMaximumZ := Max(CapturedWhiteSideMaximumZ, Vertex.Z);
    end;
    if ((Abs(Vertex.R - 15 / 255.0) < 0.0001) or
      (Abs(Vertex.R - 12 / 255.0) < 0.0001)) and
      (Abs(Vertex.G - Vertex.R) < 0.0001) and
      (Abs(Vertex.B - Vertex.R) < 0.0001) then
    begin
      CapturedBlackSideMinimumZ := Min(CapturedBlackSideMinimumZ, Vertex.Z);
      CapturedBlackSideMaximumZ := Max(CapturedBlackSideMaximumZ, Vertex.Z);
    end;
  end;

  for I := 0 to VertexNum div 4 - 1 do
  begin
    IsNoteQuad := True;
    IsWhiteQuad := True;
    QuadMaximumRadius := 0.0;
    QuadMinimumRadius := MaxDouble;
    QuadMaximumZ := -MaxDouble;
    QuadMinimumZ := MaxDouble;
    for J := 0 to 3 do
    begin
      Vertex := PVertexArray(VertexList)^[I * 4 + J];
      Radius := Sqrt(Sqr(Vertex.X) + Sqr(Vertex.Y));
      QuadMinimumRadius := Min(QuadMinimumRadius, Radius);
      QuadMaximumRadius := Max(QuadMaximumRadius, Radius);
      QuadMinimumZ := Min(QuadMinimumZ, Vertex.Z);
      QuadMaximumZ := Max(QuadMaximumZ, Vertex.Z);
      IsNoteQuad := IsNoteQuad and
        (Abs(Vertex.R - 7 / 255.0) < 0.0001) and
        (Abs(Vertex.G - 8 / 255.0) < 0.0001) and
        (Abs(Vertex.B - 9 / 255.0) < 0.0001);
      IsWhiteQuad := IsWhiteQuad and
        (Abs(Vertex.R - 242 / 255.0) < 0.0001) and
        (Abs(Vertex.G - 242 / 255.0) < 0.0001) and
        (Abs(Vertex.B - 242 / 255.0) < 0.0001);
    end;
    if IsNoteQuad then
    begin
      if QuadMaximumRadius - QuadMinimumRadius < 0.001 then
      begin
        Inc(CapturedNoteVertices, 4);
        CapturedNoteMinimumRadius := Min(CapturedNoteMinimumRadius,
          QuadMinimumRadius);
        CapturedNoteMaximumRadius := Max(CapturedNoteMaximumRadius,
          QuadMaximumRadius);
        CapturedNoteMinimumZ := Min(CapturedNoteMinimumZ, QuadMinimumZ);
        CapturedNoteMaximumZ := Max(CapturedNoteMaximumZ, QuadMaximumZ);
        LastNoteQuad := I;
      end
      else
      begin
        Inc(CapturedActiveKeyVertices, 4);
        if QuadMaximumRadius >= CapturedMaximumRadius - 0.01 then
          Inc(CapturedActiveWhiteKeyVertices, 4)
        else
          Inc(CapturedActiveBlackKeyVertices, 4);
      end;
    end;
    if IsWhiteQuad and (FirstWhiteQuad < 0) then
      FirstWhiteQuad := I;
  end;
  Result := Ord(VertexType = VERTEX_QUAD_COLOR);
end;

procedure CaptureAnchor(Width, Height: Integer); cdecl;
begin
end;

function TMockMusicData.GetFileName: string;
begin
  Result := 'circular.mid';
end;

function TMockMusicData.GetLengthSeconds: Double;
begin
  Result := 2.0;
end;

function TMockMusicData.GetNoteCount: Integer;
begin
  Result := 2;
end;

function TMockMusicData.GetNote(Index: Integer): TPianoRollNoteData;
begin
  if (Index < 0) or (Index > 1) then
    raise ERangeError.Create('note index');
  FillChar(Result, SizeOf(Result), 0);
  Result.StartSeconds := 0.5;
  Result.EndSeconds := 1.5;
  Result.Key := 60 + Index;
  Result.Velocity := 100;
  Result.TrackIndex := 0;
end;

function TMockMusicData.GetBeatCount: Integer;
begin
  Result := 2;
end;

function TMockMusicData.GetBeat(Index: Integer): TPianoRollBeatData;
begin
  if (Index < 0) or (Index > 1) then
    raise ERangeError.Create('beat index');
  FillChar(Result, SizeOf(Result), 0);
  Result.Seconds := 1.0 + Index * 0.5;
  Result.Index := Index;
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
  AutoMaximumRadius: Double;
  Data: IPianoRollMusicData;
  FlatNoteRadius: Double;
  FlatVertexCount: Integer;
  ObjectInfo: TOBJECT_INFO;
  Settings: TPianoRollDisplaySettings;
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
  Settings.CenterNote := 60;
  Settings.VisibleNoteCount := 24;
  Settings.SingleTrackColor := PianoRollColor(7, 8, 9, 255);
  Settings.DisplayTime3D := 4.0;

  Check(Settings.Radius = 0.0, 'radius default must use automatic sizing');
  Check(DrawCircularPianoRoll3D(@Video, Data, 0.75, Settings, False),
    'circular Type2 draw failed');
  Check((CapturedWhiteLaneVertices > 0) and
    (CapturedBlackLaneVertices > 0),
    'circular white/black lanes were not generated');
  Check((CapturedBeatLineVertices > 0) and
    (CapturedMeasureLineVertices > 0),
    'circular beat/measure rings were not generated');

  Settings.BeatsPerMeasure := 1;
  Check(DrawCircularPianoRoll3D(@Video, Data, 0.75, Settings, False),
    'circular measure interval draw failed');
  Check((CapturedBeatLineVertices = 0) and
    (CapturedMeasureLineVertices > 0),
    'beats-per-measure did not promote beat rings to measure rings');

  Settings.ShowLanes := False;
  Settings.ShowBeatLines := False;
  Check(DrawCircularPianoRoll3D(@Video, Data, 0.75, Settings, False),
    'circular guide visibility draw failed');
  Check((CapturedWhiteLaneVertices = 0) and
    (CapturedBlackLaneVertices = 0) and
    (CapturedBeatLineVertices = 0) and
    (CapturedMeasureLineVertices = 0),
    'circular guide visibility settings were ignored');

  Settings.BeatsPerMeasure := 4;
  Settings.ShowLanes := True;
  Settings.ShowBeatLines := True;
  Check(DrawCircularPianoRoll3D(@Video, Data, 0.75, Settings, False),
    'restored circular guide draw failed');
  Check(CapturedWhiteMaximumZ - CapturedWhiteMinimumZ < 0.01,
    'vertical Type2 keyboard was no longer an annular face');
  Check((CapturedVertexCount > 0) and
    (CapturedWhiteVertices > 0) and (CapturedBlackVertices > 0),
    'circular keyboard was not generated');
  Check((CapturedWhiteSideVertices > 0) and
    (CapturedWhiteSideMinimumZ < CapturedWhiteSideMaximumZ),
    'connected circular keyboard side was not generated');
  Check((CapturedBlackSideMinimumZ < CapturedBlackSideMaximumZ) and
    (CapturedBlackSideMinimumZ < CapturedWhiteSideMinimumZ),
    'black keys were not extruded in front of the white keyboard');
  Check(CapturedBlackMaximumRadius < CapturedMaximumRadius - 1.0,
    'Type2 black keys were not moved to the inner side');
  Check((CapturedNoteMaximumRadius <= CapturedBlackMinimumRadius + 0.01) and
    (CapturedNoteMinimumRadius < CapturedMaximumRadius - 1.0),
    'Type2 notes were not connected to the inner side');
  Check((CapturedNoteVertices > 0) and
    (CapturedNoteMinimumZ < 0.0) and (CapturedNoteMaximumZ > 0.0),
    'circular note did not cross the keyboard plane');
  Check(Abs(CapturedNoteMinimumZ) > CapturedNoteMaximumZ,
    'Type2 note time axis was not reversed');
  Check((LastNoteQuad >= 0) and (LastNoteQuad < FirstWhiteQuad),
    'circular keyboard was not appended in front of notes');
  Check((CapturedActiveKeyVertices > 0) and
    (CapturedActiveWhiteKeyVertices > 0) and
    (CapturedActiveBlackKeyVertices > 0),
    'active circular white/black keys were not recolored');
  Check(CapturedGlowVertices > 0,
    'circular strike glow was not generated after note-on');
  FlatNoteRadius := CapturedNoteMinimumRadius;
  FlatVertexCount := CapturedVertexCount;

  Settings.Note3DThickness := 12.0;
  Check(DrawCircularPianoRoll3D(@Video, Data, 0.75, Settings, False),
    'extruded circular note draw failed');
  Check(CapturedVertexCount > FlatVertexCount,
    'note 3D thickness did not add closed side faces');
  Check(CapturedNoteMaximumRadius < FlatNoteRadius - 11.0,
    'note 3D thickness did not extrude toward the circle center');
  Check(CapturedMaximumRadius <= Min(ObjectInfo.Width, ObjectInfo.Height) *
    0.5 + 0.001, 'automatic radius exceeded the screen bounds');
  AutoMaximumRadius := CapturedMaximumRadius;

  Settings.Radius := 250.0;
  Check(DrawCircularPianoRoll3D(@Video, Data, 1.0, Settings, True),
    'manual circular radius draw failed');
  Check(CapturedMaximumRadius > AutoMaximumRadius + 50.0,
    'manual radius did not enlarge the circular keyboard');
  Check(CapturedWhiteMaximumZ - CapturedWhiteMinimumZ >
    Settings.KeyLength * 0.9,
    'horizontal Type2 keyboard did not extend along the cylinder axis');
  Check(CapturedGlowVertices = 0,
    'circular strike glow did not expire');

  Video.DrawPoly := nil;
  Check(not DrawCircularPianoRoll3D(@Video, Data, 1.0, Settings, False),
    'DrawPoly absence was not reported');
  Writeln('PASS');
end.

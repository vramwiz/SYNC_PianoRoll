program SYNC_PianoRoll_HorizontalRenderTests;

// 横表示の時間方向、音階方向、鍵盤、レーン、拍線、ノート描画を検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SYNC_PianoRoll_MusicData in 'Source\Common\Data\SYNC_PianoRoll_MusicData.pas',
  SYNC_PianoRoll_PianoKeys in 'Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas',
  SYNC_PianoRoll_Colors in 'Source\Common\Color\SYNC_PianoRoll_Colors.pas',
  SYNC_PianoRoll_RGBA in 'Source\Common\Render\SYNC_PianoRoll_RGBA.pas',
  SYNC_PianoRoll_DisplayTypes in 'Source\Common\Layout\SYNC_PianoRoll_DisplayTypes.pas',
  SYNC_PianoRoll_PitchFollow in 'Source\Common\Layout\SYNC_PianoRoll_PitchFollow.pas',
  SYNC_PianoRoll_HorizontalDisplay in 'Source\Display\Horizontal\SYNC_PianoRoll_HorizontalDisplay.pas',
  SYNC_PianoRoll_Renderer in 'Source\Common\Render\SYNC_PianoRoll_Renderer.pas';

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

var
  CapturedBeatLine: Boolean;
  CapturedActiveKey: Boolean;
  CapturedBlackKey: Boolean;
  CapturedBlackLane: Boolean;
  CapturedGlow: Boolean;
  CapturedHeight: Integer;
  CapturedKeyboardLeftOfStrike: Boolean;
  CapturedMeasureLine: Boolean;
  CapturedNoteRightOfStrike: Boolean;
  CapturedStrikeLine: Boolean;
  CapturedWhiteLane: Boolean;
  CapturedWidth: Integer;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CaptureImage(Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl;
type
  TPixelArray = array[0..(MaxInt div SizeOf(TPIXEL_RGBA)) - 1] of TPIXEL_RGBA;
  PPixelArray = ^TPixelArray;

var
  I, X: Integer;
  Pixel: TPIXEL_RGBA;

  function Matches(X, Y, R, G, B, A: Integer): Boolean;
  var
    Pixel: TPIXEL_RGBA;
  begin
    if (X < 0) or (X >= Width) or (Y < 0) or (Y >= Height) then
      Exit(False);
    Pixel := PPixelArray(Buffer)^[Y * Width + X];
    Result := (Pixel.R = R) and (Pixel.G = G) and
      (Pixel.B = B) and (Pixel.A = A);
  end;

begin
  CapturedWidth := Width;
  CapturedHeight := Height;
  CapturedActiveKey := False;
  CapturedGlow := False;
  // 320x240、発音位置75%では発音線がX=80、未来側が右になる。
  CapturedStrikeLine := Matches(80, 10, 255, 255, 255, 160);
  CapturedKeyboardLeftOfStrike := Matches(30, 190, 242, 242, 242, 255);
  CapturedBlackKey := Matches(50, 176, 24, 24, 24, 255);
  CapturedNoteRightOfStrike := Matches(120, 190, 80, 210, 255, 255);
  CapturedWhiteLane := Matches(250, 190, 238, 238, 242, 28);
  CapturedBlackLane := Matches(250, 176, 110, 110, 120, 24);
  CapturedMeasureLine := Matches(110, 10, 255, 190, 80, 120);
  CapturedBeatLine := Matches(140, 10, 255, 255, 255, 48);
  for I := 0 to Width * Height - 1 do
  begin
    Pixel := PPixelArray(Buffer)^[I];
    X := I mod Width;
    if (X < 78) and (Pixel.R = 80) and (Pixel.G = 210) and
      (Pixel.B = 255) and (Pixel.A = 255) then
      CapturedActiveKey := True;
    if (Pixel.R > 220) and (Pixel.G > 220) and (Pixel.B > 220) and
      (Pixel.A > 200) and (X >= 80) and (X <= 92) then
      CapturedGlow := True;
  end;
end;

function TMockMusicData.GetFileName: string;
begin
  Result := 'horizontal_mock.mid';
end;

function TMockMusicData.GetLengthSeconds: Double;
begin
  Result := 2.0;
end;

function TMockMusicData.GetNoteCount: Integer;
begin
  Result := 1;
end;

function TMockMusicData.GetNote(Index: Integer): TPianoRollNoteData;
begin
  if Index <> 0 then
    raise ERangeError.Create('note index');
  FillChar(Result, SizeOf(Result), 0);
  Result.StartSeconds := 0.5;
  Result.EndSeconds := 1.0;
  Result.Key := 60;
  Result.Velocity := 100;
  Result.TrackIndex := 1;
end;

function TMockMusicData.GetBeatCount: Integer;
begin
  Result := 2;
end;

function TMockMusicData.GetBeat(Index: Integer): TPianoRollBeatData;
begin
  FillChar(Result, SizeOf(Result), 0);
  case Index of
    0:
      begin
        Result.Seconds := 0.5;
        Result.Index := 0;
        Result.TempoMicroseconds := 500000;
      end;
    1:
      begin
        Result.Seconds := 1.0;
        Result.Index := 1;
        Result.TempoMicroseconds := 500000;
      end;
  else
    raise ERangeError.Create('beat index');
  end;
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
  Data: IPianoRollMusicData;
  Display: IPianoRollDisplay;
  ObjectInfo: TOBJECT_INFO;
  Settings: TPianoRollDisplaySettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.ID := 11;
  ObjectInfo.EffectID := 22;
  ObjectInfo.Width := 320;
  ObjectInfo.Height := 240;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;
  Data := TMockMusicData.Create;
  Display := CreateHorizontalPianoRollDisplay;
  SetDefaultPianoRollDisplaySettings(Settings);
  // 固定画素の座標検証では初期プリセット変更の影響を受けない検査寸法を明示する。
  Settings.KeyLength := 60;
  Settings.KeyThickness := 20;
  Settings.StrikePosition := 0.75;
  Settings.VisibleNoteCount := 13;
  Settings.CenterNote := 66;

  InitializePianoRollRenderer;
  try
    Check(RenderPianoRoll(@Video, Data, 0.0, Display, Settings),
      'horizontal render failed');
    Check((CapturedWidth = 320) and (CapturedHeight = 240),
      'horizontal output size mismatch');
    Check(CapturedStrikeLine, 'horizontal strike line position mismatch');
    Check(CapturedKeyboardLeftOfStrike,
      'horizontal keyboard was not drawn left of strike');
    Check(CapturedBlackKey, 'horizontal black key was not drawn');
    Check(CapturedNoteRightOfStrike,
      'horizontal future note was not drawn right of strike');
    Check(CapturedWhiteLane, 'horizontal white lane was not drawn');
    Check(CapturedBlackLane, 'horizontal black lane was not drawn');
    Check(CapturedMeasureLine, 'horizontal measure line was not drawn');
    Check(CapturedBeatLine, 'horizontal beat line was not drawn');
    Check(not CapturedActiveKey and not CapturedGlow,
      'future horizontal note was highlighted before sounding');
    Check(RenderPianoRoll(@Video, Data, 0.5, Display, Settings),
      'active horizontal render failed');
    Check(CapturedActiveKey, 'active horizontal key was not highlighted');
    Check(CapturedGlow, 'horizontal strike glow was not drawn');
    Check(RenderPianoRoll(@Video, Data, 0.90, Display, Settings),
      'sustained horizontal render failed');
    Check(CapturedActiveKey and not CapturedGlow,
      'horizontal glow did not decay independently of the active key');
    Check(RenderPianoRoll(@Video, Data, 1.0, Display, Settings),
      'inactive horizontal render failed');
    Check(not CapturedActiveKey and not CapturedGlow,
      'horizontal strike highlight remained after note end');
    Writeln('PASS');
  finally
    Display := nil;
    FinalizePianoRollRenderer;
  end;
end.

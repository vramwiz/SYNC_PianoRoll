program SYNC_PianoRoll_RenderTests;

// 縦表示のRGBA描画、配色、寸法変更、線幅連動を検証する。

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
  SYNC_PianoRoll_VerticalDisplay in 'Source\Display\Vertical\SYNC_PianoRoll_VerticalDisplay.pas',
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
  CapturedBlackKeyPixels: Integer;
  CapturedBlackLanePixels: Integer;
  CapturedBeatLinePixels: Integer;
  CapturedCustomWhiteKeyPixels: Integer;
  CapturedDefaultSinglePixels: Integer;
  CapturedActiveKeyPixels: Integer;
  CapturedGlowPixels: Integer;
  CapturedHeight: Integer;
  CapturedMeasureLinePixels: Integer;
  CapturedOpaquePixels: Integer;
  CapturedSingleTrackPixels: Integer;
  CapturedStrikeLinePixels: Integer;
  CapturedVariation1Pixels: Integer;
  CapturedWhiteKeyPixels: Integer;
  CapturedWhiteLanePixels: Integer;
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
  I: Integer;
begin
  CapturedWidth := Width;
  CapturedHeight := Height;
  CapturedOpaquePixels := 0;
  CapturedBlackKeyPixels := 0;
  CapturedBlackLanePixels := 0;
  CapturedBeatLinePixels := 0;
  CapturedCustomWhiteKeyPixels := 0;
  CapturedDefaultSinglePixels := 0;
  CapturedActiveKeyPixels := 0;
  CapturedGlowPixels := 0;
  CapturedMeasureLinePixels := 0;
  CapturedSingleTrackPixels := 0;
  CapturedStrikeLinePixels := 0;
  CapturedVariation1Pixels := 0;
  CapturedWhiteKeyPixels := 0;
  CapturedWhiteLanePixels := 0;
  for I := 0 to Width * Height - 1 do
  begin
    if PPixelArray(Buffer)^[I].A <> 0 then
      Inc(CapturedOpaquePixels);
    if (PPixelArray(Buffer)^[I].R = 24) and
      (PPixelArray(Buffer)^[I].G = 24) and
      (PPixelArray(Buffer)^[I].B = 24) and
      (PPixelArray(Buffer)^[I].A = 255) then
      Inc(CapturedBlackKeyPixels);
    if (PPixelArray(Buffer)^[I].R = 242) and
      (PPixelArray(Buffer)^[I].G = 242) and
      (PPixelArray(Buffer)^[I].B = 242) and
      (PPixelArray(Buffer)^[I].A = 255) then
      Inc(CapturedWhiteKeyPixels);
    if (PPixelArray(Buffer)^[I].R = 238) and
      (PPixelArray(Buffer)^[I].G = 238) and
      (PPixelArray(Buffer)^[I].B = 242) and
      (PPixelArray(Buffer)^[I].A = 28) then
      Inc(CapturedWhiteLanePixels);
    if (PPixelArray(Buffer)^[I].R = 110) and
      (PPixelArray(Buffer)^[I].G = 110) and
      (PPixelArray(Buffer)^[I].B = 120) and
      (PPixelArray(Buffer)^[I].A = 24) then
      Inc(CapturedBlackLanePixels);
    if (PPixelArray(Buffer)^[I].R = 255) and
      (PPixelArray(Buffer)^[I].G = 255) and
      (PPixelArray(Buffer)^[I].B = 255) and
      (PPixelArray(Buffer)^[I].A = 48) then
      Inc(CapturedBeatLinePixels);
    if (PPixelArray(Buffer)^[I].R = 255) and
      (PPixelArray(Buffer)^[I].G = 190) and
      (PPixelArray(Buffer)^[I].B = 80) and
      (PPixelArray(Buffer)^[I].A = 120) then
      Inc(CapturedMeasureLinePixels);
    if (PPixelArray(Buffer)^[I].R = 12) and
      (PPixelArray(Buffer)^[I].G = 34) and
      (PPixelArray(Buffer)^[I].B = 56) and
      (PPixelArray(Buffer)^[I].A = 201) then
      Inc(CapturedCustomWhiteKeyPixels);
    if (PPixelArray(Buffer)^[I].R = 80) and
      (PPixelArray(Buffer)^[I].G = 210) and
      (PPixelArray(Buffer)^[I].B = 255) and
      (PPixelArray(Buffer)^[I].A = 255) then
    begin
      Inc(CapturedDefaultSinglePixels);
      if (I div Width) > Round(Height * 0.80) + 2 then
        Inc(CapturedActiveKeyPixels);
    end;
    if (PPixelArray(Buffer)^[I].R > 220) and
      (PPixelArray(Buffer)^[I].G > 220) and
      (PPixelArray(Buffer)^[I].B > 220) and
      (PPixelArray(Buffer)^[I].A > 200) and
      ((I div Width) >= Round(Height * 0.80) - 12) and
      ((I div Width) < Round(Height * 0.80)) then
      Inc(CapturedGlowPixels);
    if (PPixelArray(Buffer)^[I].R = 7) and
      (PPixelArray(Buffer)^[I].G = 8) and
      (PPixelArray(Buffer)^[I].B = 9) and
      (PPixelArray(Buffer)^[I].A = 211) then
      Inc(CapturedSingleTrackPixels);
    if (PPixelArray(Buffer)^[I].R = 255) and
      (PPixelArray(Buffer)^[I].G = 255) and
      (PPixelArray(Buffer)^[I].B = 255) and
      (PPixelArray(Buffer)^[I].A = 160) then
      Inc(CapturedStrikeLinePixels);
    if (PPixelArray(Buffer)^[I].R = 255) and
      (PPixelArray(Buffer)^[I].G = 120) and
      (PPixelArray(Buffer)^[I].B = 180) and
      (PPixelArray(Buffer)^[I].A = 255) then
      Inc(CapturedVariation1Pixels);
  end;
end;

function TMockMusicData.GetFileName: string;
begin
  Result := 'mock.mid';
end;

function TMockMusicData.GetLengthSeconds: Double;
begin
  Result := 1.0;
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
  Result.StartSeconds := 0.0;
  Result.EndSeconds := 0.5;
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
  DefaultStrikeLinePixels: Integer;
  Display: IPianoRollDisplay;
  ObjectInfo: TOBJECT_INFO;
  Settings: TPianoRollDisplaySettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.ID := 1;
  ObjectInfo.EffectID := 2;
  ObjectInfo.Width := 640;
  ObjectInfo.Height := 360;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;
  Data := TMockMusicData.Create;
  Display := CreateVerticalPianoRollDisplay;
  SetDefaultPianoRollDisplaySettings(Settings);

  InitializePianoRollRenderer;
  try
    Check(RenderPianoRoll(@Video, Data, 0.0, Display, Settings),
      'render failed');
    Check((CapturedWidth = 640) and (CapturedHeight = 360),
      'output size mismatch');
    Check(CapturedOpaquePixels > CapturedWidth * 2,
      'note rectangle was not drawn');
    Check(CapturedWhiteKeyPixels > 0, 'white keys were not drawn');
    Check(CapturedBlackKeyPixels > 0, 'black keys were not drawn');
    Check(CapturedWhiteLanePixels > 0, 'white lanes were not drawn');
    Check(CapturedBlackLanePixels > 0, 'black lanes were not drawn');
    Check(CapturedBeatLinePixels > 0, 'beat line was not drawn');
    Check(CapturedMeasureLinePixels > 0, 'measure line was not drawn');
    Check(CapturedDefaultSinglePixels > 0,
      'default single track color was not applied');
    Check(CapturedActiveKeyPixels > 0,
      'active vertical key was not highlighted');
    Check(CapturedGlowPixels > 0,
      'vertical strike glow was not drawn');
    Check(RenderPianoRoll(@Video, Data, 0.40, Display, Settings),
      'sustained vertical render failed');
    Check((CapturedActiveKeyPixels > 0) and (CapturedGlowPixels = 0),
      'vertical glow did not decay independently of the active key');
    Check(RenderPianoRoll(@Video, Data, 0.75, Display, Settings),
      'inactive vertical render failed');
    Check((CapturedActiveKeyPixels = 0) and (CapturedGlowPixels = 0),
      'vertical strike highlight remained after note end');
    DefaultStrikeLinePixels := CapturedStrikeLinePixels;

    // 大サイズでは中の初期寸法と同率で発音線も太くする。
    Settings.KeyLength := 180;
    Settings.KeyThickness := 60;
    Check(RenderPianoRoll(@Video, Data, 0.75, Display, Settings),
      'large size render failed');
    Check(CapturedStrikeLinePixels > DefaultStrikeLinePixels,
      'large size did not scale the strike line');
    Settings.KeyLength := 120;
    Settings.KeyThickness := 40;

    Settings.Palette.WhiteKey := PianoRollColor(12, 34, 56, 201);
    Check(RenderPianoRoll(@Video, Data, 0.40, Display, Settings),
      'custom palette render failed');
    Check(CapturedCustomWhiteKeyPixels > 0,
      'custom white key color was not applied');

    // バリエーション1はトラック番号を6色パレットへ割り当てる。
    Settings.TrackColorMode := ptcmVariation1;
    Check(RenderPianoRoll(@Video, Data, 0.40, Display, Settings),
      'variation 1 render failed');
    Check(CapturedVariation1Pixels > 0,
      'variation 1 track color was not applied');

    // 単色モードではトラック番号にかかわらず指定色を使う。
    Settings.TrackColorMode := ptcmSingleColor;
    Settings.SingleTrackColor := PianoRollColor(7, 8, 9, 211);
    Check(RenderPianoRoll(@Video, Data, 0.40, Display, Settings),
      'single track color render failed');
    Check(CapturedSingleTrackPixels > 0,
      'single track color was not applied');

    // 配置方式を問わず、Filter対象の寸法変更を描画座標へ反映する。
    ObjectInfo.Width := 320;
    ObjectInfo.Height := 180;
    Check(RenderPianoRoll(@Video, Data, 0.40, Display, Settings),
      'resize render failed');
    Check((CapturedWidth = 320) and (CapturedHeight = 180),
      'resized output mismatch');
    Writeln('PASS');
  finally
    Display := nil;
    FinalizePianoRollRenderer;
  end;
end.

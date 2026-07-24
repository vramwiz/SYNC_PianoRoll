program SYNC_PianoRoll_RenderTests;

// 読み取り専用ノートデータから透明RGBA映像を生成できることを検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SYNC_PianoRoll_MusicData in 'Source\Common\Data\SYNC_PianoRoll_MusicData.pas',
  SYNC_PianoRoll_PianoKeys in 'Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas',
  SYNC_PianoRoll_RGBA in 'Source\Common\Render\SYNC_PianoRoll_RGBA.pas',
  SYNC_PianoRoll_DisplayTypes in 'Source\Common\Layout\SYNC_PianoRoll_DisplayTypes.pas',
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
  CapturedHeight: Integer;
  CapturedOpaquePixels: Integer;
  CapturedWhiteKeyPixels: Integer;
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
  CapturedWhiteKeyPixels := 0;
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
  Data: IPianoRollMusicData;
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

    ObjectInfo.Width := 320;
    ObjectInfo.Height := 180;
    Check(RenderPianoRoll(@Video, Data, 0.0, Display, Settings),
      'resize render failed');
    Check((CapturedWidth = 320) and (CapturedHeight = 180),
      'resized output mismatch');
    Writeln('PASS');
  finally
    Display := nil;
    FinalizePianoRollRenderer;
  end;
end.

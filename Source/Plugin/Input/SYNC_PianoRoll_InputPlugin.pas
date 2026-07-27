unit SYNC_PianoRoll_InputPlugin;

// ファイル名で指定された寸法・時間の透明ベース映像をInputとして提供する。

interface

uses
  Winapi.Windows,
  AviUtl2InputTypes;

function PianoRollInputOpen(FileName: LPCWSTR): INPUT_HANDLE;
function PianoRollInputClose(Ih: INPUT_HANDLE): BOOL;
function PianoRollInputGetInfo(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL;
function PianoRollInputReadVideo(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer;
function PianoRollInputConfig(Hwnd: HWND; Hinst: HINST): BOOL;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_PianoRoll_FrameShared;

type
  PPianoRollInputContext = ^TPianoRollInputContext;
  TPianoRollInputContext = record
    Width : Integer;
    Height: Integer;
    MaxSec: Double;
    Rate  : Integer;
    Scale : Integer;
    Info  : BITMAPINFOHEADER;
  end;

procedure ParseBaseFileName(const FileName: string; out Width, Height: Integer;
  out MaxSec: Double; out Rate, Scale: Integer);
var
  Base : string;
  Fps  : Double;
  Parts: TArray<string>;
begin
  // 形式: Width_Height_MaxSec_Fps_Scale.syncpianoroll
  Width := 1;
  Height := 1;
  MaxSec := 3600.0;
  Fps := 30.0;
  Scale := 1;

  Base := ChangeFileExt(ExtractFileName(FileName), '');
  Parts := Base.Split(['_']);
  if Length(Parts) >= 2 then
  begin
    Width := StrToIntDef(Parts[0], Width);
    Height := StrToIntDef(Parts[1], Height);
  end;
  if Length(Parts) >= 3 then
    MaxSec := StrToFloatDef(Parts[2], MaxSec);
  if Length(Parts) >= 4 then
    Fps := StrToFloatDef(Parts[3], Fps);
  if Length(Parts) >= 5 then
    Scale := StrToIntDef(Parts[4], Scale);

  Width := Max(1, Width);
  Height := Max(1, Height);
  MaxSec := Max(0.0, MaxSec);
  Scale := Max(1, Scale);
  Rate := Max(1, Round(Fps * Scale));
end;

function PianoRollInputOpen(FileName: LPCWSTR): INPUT_HANDLE;
var
  Context: PPianoRollInputContext;
begin
  Result := nil;
  New(Context);
  FillChar(Context^, SizeOf(Context^), 0);
  try
    ParseBaseFileName(string(FileName), Context^.Width, Context^.Height,
      Context^.MaxSec, Context^.Rate, Context^.Scale);
    Context^.Info.biSize := SizeOf(BITMAPINFOHEADER);
    Context^.Info.biWidth := Context^.Width;
    Context^.Info.biHeight := Context^.Height;
    Context^.Info.biPlanes := 1;
    Context^.Info.biBitCount := 32;
    Context^.Info.biCompression := BI_RGB;
    Context^.Info.biSizeImage := Context^.Width * Context^.Height * 4;
    Result := Context;
  except
    Dispose(Context);
  end;
end;

function PianoRollInputClose(Ih: INPUT_HANDLE): BOOL;
begin
  Result := False;
  if Ih = nil then
    Exit;
  Dispose(PPianoRollInputContext(Ih));
  Result := True;
end;

function PianoRollInputGetInfo(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL;
var
  Context: PPianoRollInputContext;
begin
  Result := False;
  if (Ih = nil) or (Info = nil) then
    Exit;

  Context := PPianoRollInputContext(Ih);
  FillChar(Info^, SizeOf(TInputInfo), 0);
  Info^.flag := INPUT_INFO_FLAG_VIDEO;
  Info^.rate := Context^.Rate;
  Info^.scale := Context^.Scale;
  Info^.n := Ceil(Context^.MaxSec * Context^.Rate / Context^.Scale);
  Info^.format := @Context^.Info;
  Info^.format_size := SizeOf(BITMAPINFOHEADER);
  Result := True;
end;

function PianoRollInputReadVideo(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer;
var
  Context: PPianoRollInputContext;
begin
  Result := 0;
  if (Ih = nil) or (Buf = nil) then
    Exit;

  Context := PPianoRollInputContext(Ih);
  FillChar(Buf^, Context^.Info.biSizeImage, 0);
  // 旧共有フレーム経路の互換確認用に発行し、現行Filterはこの値へ依存しない。
  PublishPianoRollFrame(Frame, Context^.Rate, Context^.Scale);
  Result := Context^.Info.biSizeImage;
end;

function PianoRollInputConfig(Hwnd: HWND; Hinst: HINST): BOOL;
begin
  MessageBox(Hwnd,
    'ピアノロール描画用のフレーム位置入力プラグインです。',
    'ピアノロールベース', MB_OK or MB_ICONINFORMATION);
  Result := True;
end;

end.

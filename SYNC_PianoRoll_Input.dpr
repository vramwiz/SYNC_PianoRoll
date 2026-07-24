library SYNC_PianoRoll_Input;

// ピアノロール描画用の時刻ベースを提供する AviUtl2 入力プラグイン。

uses
  Winapi.Windows,
  AviUtl2InputTypes in 'Source\Lib\AviUtl2InputTypes.pas',
  SYNC_PianoRoll_InputPlugin in 'Source\SYNC_PianoRoll_InputPlugin.pas';

function func_open(FileName: LPCWSTR): INPUT_HANDLE; cdecl;
begin
  Result := PianoRollInputOpen(FileName);
end;

function func_close(Ih: INPUT_HANDLE): BOOL; cdecl;
begin
  Result := PianoRollInputClose(Ih);
end;

function func_info_get(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL; cdecl;
begin
  Result := PianoRollInputGetInfo(Ih, Info);
end;

function func_read_video(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer; cdecl;
begin
  Result := PianoRollInputReadVideo(Ih, Frame, Buf);
end;

function func_read_audio(Ih: INPUT_HANDLE; Start, Length: Integer; Buf: Pointer): Integer; cdecl;
begin
  Result := 0;
end;

function func_config(Hwnd: HWND; Hinst: HINST): BOOL; cdecl;
begin
  Result := PianoRollInputConfig(Hwnd, Hinst);
end;

var
  Plugin: TInputPluginTable = (
    flag: INPUT_PLUGIN_FLAG_VIDEO;
    name: 'SYNC_ピアノロール_Input';
    filefilter: 'ピアノロールベース (*.syncpianoroll)'#0'*.syncpianoroll'#0;
    information: 'ピアノロール描画用フレーム位置入力';
    func_open: func_open;
    func_close: func_close;
    func_info_get: func_info_get;
    func_read_video: func_read_video;
    func_read_audio: func_read_audio;
    func_config: func_config;
    func_set_track: nil;
    func_time_to_frame: nil
  );

function GetInputPluginTable: PInputPluginTable; cdecl;
begin
  Result := @Plugin;
end;

exports
  GetInputPluginTable name 'GetInputPluginTable';

begin
end.

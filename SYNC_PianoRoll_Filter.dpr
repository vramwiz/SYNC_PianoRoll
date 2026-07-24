library SYNC_PianoRoll_Filter;

// ピアノロールフィルターの AviUtl2 DLL 境界。

{$ALIGN 8}

uses
  Winapi.Windows,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_PianoRoll_FrameShared in 'Source\Lib\SYNC_PianoRoll_FrameShared.pas',
  SYNC_PianoRoll_ContextManager in 'Source\SYNC_PianoRoll_ContextManager.pas',
  SYNC_PianoRoll_FilterPlugin in 'Source\SYNC_PianoRoll_FilterPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  InitializePianoRollFilter;
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizePianoRollFilter;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetPianoRollFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.

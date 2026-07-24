program SYNC_PianoRoll_PluginLoadTests;

// Filter DLLの登録表と音楽ファイル項目のnil終端を検証する。

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils;

type
  TGetFilterPluginTable = function: Pointer; cdecl;
  TFileItem = record
    ItemType: PWideChar;
    Name: PWideChar;
    Value: PWideChar;
    FileFilter: PWideChar;
  end;
  PFileItem = ^TFileItem;

  TPluginTable = record
    Flag: Integer;
    Name, Label_, Information: PWideChar;
    Items: ^Pointer;
    FuncProcVideo, FuncProcAudio: Pointer;
  end;
  PPluginTable = ^TPluginTable;

  TItemArray = array[0..1] of Pointer;
  PItemArray = ^TItemArray;

var
  FileItem: PFileItem;
  GetTable: TGetFilterPluginTable;
  Items: PItemArray;
  ModuleHandle: HMODULE;
  Table: PPluginTable;
begin
  if ParamCount <> 1 then
    raise Exception.Create('plugin path is required');

  ModuleHandle := LoadLibrary(PChar(ParamStr(1)));
  if ModuleHandle = 0 then
    RaiseLastOSError;
  try
    GetTable := TGetFilterPluginTable(
      GetProcAddress(ModuleHandle, 'GetFilterPluginTable'));
    if not Assigned(GetTable) then
      raise Exception.Create('GetFilterPluginTable export is missing');
    Table := PPluginTable(GetTable());
    if Table = nil then
      raise Exception.Create('plugin table is nil');
    if string(Table^.Name) <> 'SYNC_ピアノロール_Filter' then
      raise Exception.Create('plugin name mismatch');

    Items := PItemArray(Table^.Items);
    if (Items = nil) or (Items^[0] = nil) or (Items^[1] <> nil) then
      raise Exception.Create('plugin items are not terminated');
    FileItem := PFileItem(Items^[0]);
    if string(FileItem^.ItemType) <> 'file' then
      raise Exception.Create('music file item type mismatch');
    if string(FileItem^.Name) <> '音楽ファイル' then
      raise Exception.Create('music file item name mismatch');
    Writeln('PASS');
  finally
    FreeLibrary(ModuleHandle);
  end;
end.

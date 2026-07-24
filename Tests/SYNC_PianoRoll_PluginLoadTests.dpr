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

  TTrackItem = record
    ItemType: PWideChar;
    Name: PWideChar;
    Value, S, E, Step: Double;
  end;
  PTrackItem = ^TTrackItem;

  TColorItem = record
    ItemType: PWideChar;
    Name: PWideChar;
    B, G, R, X: Byte;
  end;
  PColorItem = ^TColorItem;

  TSelectListItem = record
    Name: PWideChar;
    Value: Integer;
  end;
  PSelectListItem = ^TSelectListItem;
  TSelectListArray = array[0..2] of TSelectListItem;
  PSelectListArray = ^TSelectListArray;

  TSelectItem = record
    ItemType: PWideChar;
    Name: PWideChar;
    Value: Integer;
    List: PSelectListItem;
  end;
  PSelectItem = ^TSelectItem;

  TItemHeader = record
    ItemType: PWideChar;
    Name: PWideChar;
  end;
  PItemHeader = ^TItemHeader;

  TPluginTable = record
    Flag: Integer;
    Name, Label_, Information: PWideChar;
    Items: ^Pointer;
    FuncProcVideo, FuncProcAudio: Pointer;
  end;
  PPluginTable = ^TPluginTable;

  TItemArray = array[0..20] of Pointer;
  PItemArray = ^TItemArray;

var
  FileItem: PFileItem;
  GetTable: TGetFilterPluginTable;
  I: Integer;
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
    if Items = nil then
      raise Exception.Create('plugin items are nil');
    for I := 0 to 19 do
      if Items^[I] = nil then
        raise Exception.CreateFmt('plugin item %d is nil', [I]);
    if Items^[20] <> nil then
      raise Exception.Create('plugin items are not terminated');
    FileItem := PFileItem(Items^[0]);
    if string(FileItem^.ItemType) <> 'file' then
      raise Exception.Create('music file item type mismatch');
    if string(FileItem^.Name) <> '音楽ファイル' then
      raise Exception.Create('music file item name mismatch');

    if (string(PItemHeader(Items^[1])^.ItemType) <> 'track') or
      (string(PItemHeader(Items^[1])^.Name) <> '表示時間 (秒)') or
      (PTrackItem(Items^[1])^.Value <> 4.0) then
      raise Exception.Create('display time item mismatch');
    if string(PItemHeader(Items^[2])^.Name) <> '発音位置 (%)' then
      raise Exception.Create('strike position item mismatch');
    if string(PItemHeader(Items^[3])^.Name) <> 'ずらし (秒)' then
      raise Exception.Create('time shift item mismatch');
    if string(PItemHeader(Items^[4])^.Name) <> '最低音' then
      raise Exception.Create('lowest key item mismatch');
    if string(PItemHeader(Items^[5])^.Name) <> '最高音' then
      raise Exception.Create('highest key item mismatch');
    if (string(PItemHeader(Items^[6])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[6])^.Name) <> '音域') then
      raise Exception.Create('auto key range item mismatch');
    if string(PItemHeader(Items^[7])^.Name) <> '鍵盤の長さ' then
      raise Exception.Create('key length item mismatch');
    if string(PItemHeader(Items^[8])^.Name) <> '鍵盤の太さ' then
      raise Exception.Create('key thickness item mismatch');
    if string(PItemHeader(Items^[9])^.Name) <> 'ノート太さ (%)' then
      raise Exception.Create('note thickness item mismatch');
    if string(PItemHeader(Items^[10])^.Name) <> 'レーン表示' then
      raise Exception.Create('lane visibility item mismatch');
    if string(PItemHeader(Items^[11])^.Name) <> '拍線表示' then
      raise Exception.Create('beat visibility item mismatch');
    if string(PItemHeader(Items^[12])^.Name) <> '1小節の拍数' then
      raise Exception.Create('beats per measure item mismatch');
    if (string(PItemHeader(Items^[13])^.ItemType) <> 'color') or
      (string(PItemHeader(Items^[13])^.Name) <> '白鍵色') then
      raise Exception.Create('white key color item mismatch');
    if string(PItemHeader(Items^[14])^.Name) <> '黒鍵色' then
      raise Exception.Create('black key color item mismatch');
    if string(PItemHeader(Items^[15])^.Name) <> '白鍵レーン色' then
      raise Exception.Create('white lane color item mismatch');
    if string(PItemHeader(Items^[16])^.Name) <> '黒鍵レーン色' then
      raise Exception.Create('black lane color item mismatch');
    if string(PItemHeader(Items^[17])^.Name) <> '拍線色' then
      raise Exception.Create('beat line color item mismatch');
    if string(PItemHeader(Items^[18])^.Name) <> '小節線色' then
      raise Exception.Create('measure line color item mismatch');
    if string(PItemHeader(Items^[19])^.Name) <> '発音線色' then
      raise Exception.Create('strike line color item mismatch');
    if (PColorItem(Items^[13])^.R <> 242) or
      (PColorItem(Items^[13])^.G <> 242) or
      (PColorItem(Items^[13])^.B <> 242) or
      (PColorItem(Items^[13])^.X <> 0) then
      raise Exception.Create('white key default color mismatch');
    if (PColorItem(Items^[18])^.R <> 255) or
      (PColorItem(Items^[18])^.G <> 190) or
      (PColorItem(Items^[18])^.B <> 80) or
      (PColorItem(Items^[18])^.X <> 0) then
      raise Exception.Create('measure line default color mismatch');

    if (PSelectItem(Items^[6])^.List = nil) or
      (PSelectListArray(PSelectItem(Items^[6])^.List)^[2].Name <> nil) then
      raise Exception.Create('key range select list is not terminated');
    if (PSelectItem(Items^[10])^.List = nil) or
      (PSelectListArray(PSelectItem(Items^[10])^.List)^[2].Name <> nil) then
      raise Exception.Create('visibility select list is not terminated');
    Writeln('PASS');
  finally
    FreeLibrary(ModuleHandle);
  end;
end.

program SYNC_PianoRoll_PluginLoadTests;

// Filter DLLの登録項目、初期値、選択肢配列のnil終端を検証する。

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
  TSingleChoiceListArray = array[0..1] of TSelectListItem;
  PSingleChoiceListArray = ^TSingleChoiceListArray;
  TColorModeListArray = array[0..15] of TSelectListItem;
  PColorModeListArray = ^TColorModeListArray;
  TSizePresetListArray = array[0..2] of TSelectListItem;
  PSizePresetListArray = ^TSizePresetListArray;
  TPitchFollowListArray = array[0..3] of TSelectListItem;
  PPitchFollowListArray = ^TPitchFollowListArray;

  TSelectItem = record
    ItemType: PWideChar;
    Name: PWideChar;
    Value: Integer;
    List: PSelectListItem;
  end;
  PSelectItem = ^TSelectItem;

  TButtonItem = record
    ItemType: PWideChar;
    Name: PWideChar;
    Callback: Pointer;
  end;
  PButtonItem = ^TButtonItem;

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

  TItemArray = array[0..38] of Pointer;
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
    // 単体配置とInputベースへの追加で共用する映像生成登録を維持する。
    if Table^.Flag <> 1 then
      raise Exception.Create('plugin is not registered as a standalone filter');

    Items := PItemArray(Table^.Items);
    if Items = nil then
      raise Exception.Create('plugin items are nil');
    for I := 0 to 37 do
      if Items^[I] = nil then
        raise Exception.CreateFmt('plugin item %d is nil', [I]);
    if Items^[38] <> nil then
      raise Exception.Create('plugin items are not terminated');
    FileItem := PFileItem(Items^[0]);
    if string(FileItem^.ItemType) <> 'file' then
      raise Exception.Create('music file item type mismatch');
    if string(FileItem^.Name) <> '音楽ファイル' then
      raise Exception.Create('music file item name mismatch');

    if (string(PItemHeader(Items^[1])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[1])^.Name) <> '表示分類') or
      (PSelectItem(Items^[1])^.Value <> 0) then
      raise Exception.Create('display category item mismatch');
    if (string(PItemHeader(Items^[2])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[2])^.Name) <> '描画方式') or
      (PSelectItem(Items^[2])^.Value <> 0) then
      raise Exception.Create('render dimension item mismatch');
    if (string(PItemHeader(Items^[3])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[3])^.Name) <> '表示タイプ') or
      (PSelectItem(Items^[3])^.Value <> 0) then
      raise Exception.Create('style type item mismatch');
    if (string(PItemHeader(Items^[4])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[4])^.Name) <> '方向') or
      (PSelectItem(Items^[4])^.Value <> 0) then
      raise Exception.Create('orientation item mismatch');
    if (string(PItemHeader(Items^[5])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[5])^.Name) <> '鍵盤タイプ') or
      (PSelectItem(Items^[5])^.Value <> 0) then
      raise Exception.Create('keyboard type item mismatch');
    if (string(PItemHeader(Items^[6])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[6])^.Name) <> 'サイズ') or
      (PSelectItem(Items^[6])^.Value <> 1) then
      raise Exception.Create('size preset item mismatch');
    if (string(PItemHeader(Items^[7])^.ItemType) <> 'button') or
      (string(PItemHeader(Items^[7])^.Name) <> 'サイズ適用') or
      (PButtonItem(Items^[7])^.Callback = nil) then
      raise Exception.Create('size preset button mismatch');
    if (string(PItemHeader(Items^[8])^.ItemType) <> 'track') or
      (string(PItemHeader(Items^[8])^.Name) <> '表示時間 (秒)') or
      (PTrackItem(Items^[8])^.Value <> 4.0) then
      raise Exception.Create('display time item mismatch');
    if (string(PItemHeader(Items^[9])^.Name) <> '表示時間 3D (秒)') or
      (PTrackItem(Items^[9])^.Value <> 30.0) then
      raise Exception.Create('3D display time item mismatch');
    if string(PItemHeader(Items^[10])^.Name) <> '発音位置 (%)' then
      raise Exception.Create('strike position item mismatch');
    if string(PItemHeader(Items^[11])^.Name) <> 'ずらし (秒)' then
      raise Exception.Create('time shift item mismatch');
    if (string(PItemHeader(Items^[12])^.Name) <> '表示音階数') or
      (PTrackItem(Items^[12])^.Value <> 64) then
      raise Exception.Create('visible note count item mismatch');
    if (string(PItemHeader(Items^[13])^.Name) <> '中央ノート') or
      (PTrackItem(Items^[13])^.Value <> 64) then
      raise Exception.Create('center note item mismatch');
    if (string(PItemHeader(Items^[14])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[14])^.Name) <> '音域追従') then
      raise Exception.Create('pitch follow item mismatch');
    if string(PItemHeader(Items^[15])^.Name) <> '鍵盤の長さ' then
      raise Exception.Create('key length item mismatch');
    if PTrackItem(Items^[15])^.Value <> 120 then
      raise Exception.Create('key length default mismatch');
    if string(PItemHeader(Items^[16])^.Name) <> '鍵盤の太さ' then
      raise Exception.Create('key thickness item mismatch');
    if PTrackItem(Items^[16])^.Value <> 40 then
      raise Exception.Create('key thickness default mismatch');
    if string(PItemHeader(Items^[17])^.Name) <> 'ノート太さ (%)' then
      raise Exception.Create('note thickness item mismatch');
    if (string(PItemHeader(Items^[18])^.Name) <> '白鍵3D厚み') or
      (PTrackItem(Items^[18])^.Value <> 0) then
      raise Exception.Create('white key 3D thickness item mismatch');
    if (string(PItemHeader(Items^[19])^.Name) <> '黒鍵3D厚み') or
      (PTrackItem(Items^[19])^.Value <> 0) then
      raise Exception.Create('black key 3D thickness item mismatch');
    if (string(PItemHeader(Items^[20])^.Name) <> 'ノート3D厚み') or
      (PTrackItem(Items^[20])^.Value <> 0) then
      raise Exception.Create('note 3D thickness item mismatch');
    if string(PItemHeader(Items^[21])^.Name) <> 'レーン表示' then
      raise Exception.Create('lane visibility item mismatch');
    if string(PItemHeader(Items^[22])^.Name) <> '拍線表示' then
      raise Exception.Create('beat visibility item mismatch');
    if string(PItemHeader(Items^[23])^.Name) <> '1小節の拍数' then
      raise Exception.Create('beats per measure item mismatch');
    if (string(PItemHeader(Items^[24])^.ItemType) <> 'color') or
      (string(PItemHeader(Items^[24])^.Name) <> '白鍵色') then
      raise Exception.Create('white key color item mismatch');
    if string(PItemHeader(Items^[25])^.Name) <> '黒鍵色' then
      raise Exception.Create('black key color item mismatch');
    if string(PItemHeader(Items^[26])^.Name) <> '白鍵レーン色' then
      raise Exception.Create('white lane color item mismatch');
    if string(PItemHeader(Items^[27])^.Name) <> '黒鍵レーン色' then
      raise Exception.Create('black lane color item mismatch');
    if string(PItemHeader(Items^[28])^.Name) <> '拍線色' then
      raise Exception.Create('beat line color item mismatch');
    if string(PItemHeader(Items^[29])^.Name) <> '小節線色' then
      raise Exception.Create('measure line color item mismatch');
    if string(PItemHeader(Items^[30])^.Name) <> '発音線色' then
      raise Exception.Create('strike line color item mismatch');
    if (string(PItemHeader(Items^[31])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[31])^.Name) <> 'ノート配色') or
      (PSelectItem(Items^[31])^.Value <> 0) then
      raise Exception.Create('track color mode item mismatch');
    if (string(PItemHeader(Items^[32])^.ItemType) <> 'color') or
      (string(PItemHeader(Items^[32])^.Name) <> 'ノート単色') then
      raise Exception.Create('single track color item mismatch');
    if (string(PItemHeader(Items^[33])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[33])^.Name) <> 'ノート立体表示') or
      (PSelectItem(Items^[33])^.Value <> 1) then
      raise Exception.Create('note depth item mismatch');
    if (string(PItemHeader(Items^[34])^.ItemType) <> 'color') or
      (string(PItemHeader(Items^[34])^.Name) <> 'グラデ色1') or
      (PColorItem(Items^[34])^.R <> 255) or
      (PColorItem(Items^[34])^.G <> 0) or
      (PColorItem(Items^[34])^.B <> 0) then
      raise Exception.Create('gradient color 1 item mismatch');
    if (string(PItemHeader(Items^[35])^.ItemType) <> 'color') or
      (string(PItemHeader(Items^[35])^.Name) <> 'グラデ色2') or
      (PColorItem(Items^[35])^.R <> 0) or
      (PColorItem(Items^[35])^.G <> 0) or
      (PColorItem(Items^[35])^.B <> 255) then
      raise Exception.Create('gradient color 2 item mismatch');
    if (string(PItemHeader(Items^[36])^.ItemType) <> 'select') or
      (string(PItemHeader(Items^[36])^.Name) <> '発音エフェクト') or
      (PSelectItem(Items^[36])^.Value <> 0) then
      raise Exception.Create('strike effect type item mismatch');
    if (string(PItemHeader(Items^[37])^.ItemType) <> 'track') or
      (string(PItemHeader(Items^[37])^.Name) <> '半径') or
      (PTrackItem(Items^[37])^.Value <> 0) then
      raise Exception.Create('radius item mismatch');
    if (PColorItem(Items^[24])^.R <> 242) or
      (PColorItem(Items^[24])^.G <> 242) or
      (PColorItem(Items^[24])^.B <> 242) or
      (PColorItem(Items^[24])^.X <> 0) then
      raise Exception.Create('white key default color mismatch');
    if (PColorItem(Items^[29])^.R <> 255) or
      (PColorItem(Items^[29])^.G <> 190) or
      (PColorItem(Items^[29])^.B <> 80) or
      (PColorItem(Items^[29])^.X <> 0) then
      raise Exception.Create('measure line default color mismatch');
    if (PColorItem(Items^[32])^.R <> 80) or
      (PColorItem(Items^[32])^.G <> 210) or
      (PColorItem(Items^[32])^.B <> 255) or
      (PColorItem(Items^[32])^.X <> 0) then
      raise Exception.Create('single track default color mismatch');

    if (PSelectItem(Items^[5])^.List = nil) or
      (string(PSelectListArray(
        PSelectItem(Items^[5])^.List)^[0].Name) <> '標準ピアノ') or
      (string(PSelectListArray(
        PSelectItem(Items^[5])^.List)^[1].Name) <> 'ハープ（7音）') or
      (PSelectListArray(PSelectItem(Items^[5])^.List)^[2].Name <> nil) then
      raise Exception.Create('keyboard type select list mismatch');
    if (PSelectItem(Items^[14])^.List = nil) or
      (string(PPitchFollowListArray(
        PSelectItem(Items^[14])^.List)^[0].Name) <> '追従しない') or
      (string(PPitchFollowListArray(
        PSelectItem(Items^[14])^.List)^[1].Name) <> '常に追従') or
      (string(PPitchFollowListArray(
        PSelectItem(Items^[14])^.List)^[2].Name) <>
        'はみ出したとき追従') or
      (PPitchFollowListArray(
        PSelectItem(Items^[14])^.List)^[3].Name <> nil) then
      raise Exception.Create('pitch follow select list mismatch');
    if (PSelectItem(Items^[21])^.List = nil) or
      (PSelectListArray(PSelectItem(Items^[21])^.List)^[2].Name <> nil) then
      raise Exception.Create('visibility select list is not terminated');
    if (PSelectItem(Items^[31])^.List = nil) or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[0].Name) <>
        '単色') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[1].Name) <>
        'バリエーション1') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[2].Name) <> 'トラック：DOS') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[5].Name) <> 'トラック：暗色') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[6].Name) <> '音階：DOS') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[9].Name) <> '音階：暗色') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[10].Name) <> 'ドレミ：虹') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[12].Name) <> 'ドレミ：暗色') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[13].Name) <> 'グラデ色：RGB') or
      (string(PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[14].Name) <> 'グラデ色：HSV') or
      (PColorModeListArray(
        PSelectItem(Items^[31])^.List)^[15].Name <> nil) then
      raise Exception.Create('track color mode list mismatch');
    if (PSelectItem(Items^[1])^.List = nil) or
      (string(PSingleChoiceListArray(
        PSelectItem(Items^[1])^.List)^[0].Name) <> 'ピアノ') or
      (PSingleChoiceListArray(
        PSelectItem(Items^[1])^.List)^[1].Name <> nil) then
      raise Exception.Create('display category list mismatch');
    if (PSelectItem(Items^[2])^.List = nil) or
      (string(PSelectListArray(
        PSelectItem(Items^[2])^.List)^[0].Name) <> '2D') or
      (string(PSelectListArray(
        PSelectItem(Items^[2])^.List)^[1].Name) <> '3D') or
      (PSelectListArray(
        PSelectItem(Items^[2])^.List)^[2].Name <> nil) then
      raise Exception.Create('render dimension list mismatch');
    if (PSelectItem(Items^[3])^.List = nil) or
      (string(PSelectListArray(
        PSelectItem(Items^[3])^.List)^[0].Name) <> 'Type1') or
      (string(PSelectListArray(
        PSelectItem(Items^[3])^.List)^[1].Name) <> 'Type2') or
      (PSelectListArray(
        PSelectItem(Items^[3])^.List)^[2].Name <> nil) then
      raise Exception.Create('style type list mismatch');
    if (PSelectItem(Items^[4])^.List = nil) or
      (string(PSelectListArray(
        PSelectItem(Items^[4])^.List)^[0].Name) <> '縦') or
      (string(PSelectListArray(
        PSelectItem(Items^[4])^.List)^[1].Name) <> '横') or
      (PSelectListArray(
        PSelectItem(Items^[4])^.List)^[2].Name <> nil) then
      raise Exception.Create('orientation list mismatch');
    if (PSelectItem(Items^[6])^.List = nil) or
      (string(PSizePresetListArray(
        PSelectItem(Items^[6])^.List)^[0].Name) <> '中') or
      (string(PSizePresetListArray(
        PSelectItem(Items^[6])^.List)^[1].Name) <> '大') or
      (PSizePresetListArray(
        PSelectItem(Items^[6])^.List)^[2].Name <> nil) then
      raise Exception.Create('size preset list mismatch');
    if (PSelectItem(Items^[33])^.List = nil) or
      (string(PSelectListArray(
        PSelectItem(Items^[33])^.List)^[0].Name) <> '平面') or
      (string(PSelectListArray(
        PSelectItem(Items^[33])^.List)^[1].Name) <> '立体') or
      (PSelectListArray(
        PSelectItem(Items^[33])^.List)^[2].Name <> nil) then
      raise Exception.Create('note depth select list mismatch');
    if (PSelectItem(Items^[36])^.List = nil) or
      (string(PSingleChoiceListArray(
        PSelectItem(Items^[36])^.List)^[0].Name) <> 'Type1') or
      (PSingleChoiceListArray(
        PSelectItem(Items^[36])^.List)^[1].Name <> nil) then
      raise Exception.Create('strike effect type list mismatch');
    Writeln('PASS');
  finally
    FreeLibrary(ModuleHandle);
  end;
end.

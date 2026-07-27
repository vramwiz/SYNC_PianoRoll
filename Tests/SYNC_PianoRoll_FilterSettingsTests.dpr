program SYNC_PianoRoll_FilterSettingsTests;

// 実Filter DLLへ音域項目値を渡し、描画結果へ反映されることを検証する。

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas';

type
  TGetFilterPluginTable = function: PFILTER_PLUGIN_TABLE; cdecl;
  TInitializePlugin = function(Version: DWORD): Byte; cdecl;
  TUninitializePlugin = procedure; cdecl;
  TItemArray = array[0..25] of Pointer;
  PItemArray = ^TItemArray;

var
  CapturedOpaquePixels: Integer;
  CapturedPresetLength: string;
  CapturedPresetNoteThickness: string;
  CapturedPresetThickness: string;

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
  CapturedOpaquePixels := 0;
  for I := 0 to Width * Height - 1 do
    if PPixelArray(Buffer)^[I].A <> 0 then
      Inc(CapturedOpaquePixels);
end;

function GetMockFocusObject: OBJECT_HANDLE; cdecl;
begin
  Result := Pointer(1);
end;

function SetMockObjectItemValue(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
  Item: LPCWSTR; Value: PAnsiChar): Byte; cdecl;
var
  ValueText: string;
begin
  Result := 0;
  if (Obj = nil) or (string(Effect) <> 'SYNC_ピアノロール_Filter') then
    Exit;
  ValueText := UTF8ToString(UTF8String(Value));
  if string(Item) = '鍵盤の長さ' then
    CapturedPresetLength := ValueText
  else if string(Item) = '鍵盤の太さ' then
    CapturedPresetThickness := ValueText
  else if string(Item) = 'ノート太さ (%)' then
    CapturedPresetNoteThickness := ValueText
  else
    Exit;
  Result := 1;
end;

procedure WriteMinimalMidi(const FileName: string);
const
  MidiData: array[0..34] of Byte = (
    $4D, $54, $68, $64, $00, $00, $00, $06,
    $00, $00, $00, $01, $01, $E0,
    $4D, $54, $72, $6B, $00, $00, $00, $0D,
    $00, $90, $3C, $64,
    $83, $60, $80, $3C, $00,
    $00, $FF, $2F, $00
  );
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(MidiData, SizeOf(MidiData));
  finally
    Stream.Free;
  end;
end;

var
  FullRangePixels, SingleRangePixels: Integer;
  Edit: TEDIT_SECTION;
  GetTable: TGetFilterPluginTable;
  InitializePlugin: TInitializePlugin;
  Items: PItemArray;
  MidiFileName: string;
  ModuleHandle: HMODULE;
  ObjectInfo: TOBJECT_INFO;
  Table: PFILTER_PLUGIN_TABLE;
  UninitializePlugin: TUninitializePlugin;
  Video: TFILTER_PROC_VIDEO;
begin
  if ParamCount <> 1 then
    raise Exception.Create('plugin path is required');
  MidiFileName := TPath.Combine(TPath.GetTempPath,
    'SYNC_PianoRoll_FilterSettings_' + TGUID.NewGuid.ToString + '.mid');
  WriteMinimalMidi(MidiFileName);
  ModuleHandle := LoadLibrary(PChar(ParamStr(1)));
  if ModuleHandle = 0 then
    RaiseLastOSError;
  try
    InitializePlugin := TInitializePlugin(
      GetProcAddress(ModuleHandle, 'InitializePlugin'));
    UninitializePlugin := TUninitializePlugin(
      GetProcAddress(ModuleHandle, 'UninitializePlugin'));
    GetTable := TGetFilterPluginTable(
      GetProcAddress(ModuleHandle, 'GetFilterPluginTable'));
    Check(Assigned(InitializePlugin) and Assigned(UninitializePlugin) and
      Assigned(GetTable), 'required export is missing');
    Check(InitializePlugin(0) <> 0, 'plugin initialization failed');
    try
      Table := GetTable();
      Check((Table <> nil) and Assigned(Table^.Func_Proc_Video),
        'video callback is missing');
      Items := PItemArray(Table^.Items);
      Check(Items <> nil, 'plugin items are missing');
      PFILTER_ITEM_FILE(Items^[0])^.Value := PWideChar(MidiFileName);

      FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
      FillChar(Video, SizeOf(Video), 0);
      ObjectInfo.ID := 901;
      ObjectInfo.EffectID := 902;
      ObjectInfo.Width := 640;
      ObjectInfo.Height := 360;
      Video.Object_ := @ObjectInfo;
      Video.SetImageData := CaptureImage;

      PFILTER_ITEM_TRACK(Items^[4])^.Value := 128;
      PFILTER_ITEM_TRACK(Items^[5])^.Value := 64;
      CapturedOpaquePixels := 0;
      Table^.Func_Proc_Video(@Video);
      FullRangePixels := CapturedOpaquePixels;

      PFILTER_ITEM_TRACK(Items^[4])^.Value := 1;
      PFILTER_ITEM_TRACK(Items^[5])^.Value := 60;
      CapturedOpaquePixels := 0;
      Table^.Func_Proc_Video(@Video);
      SingleRangePixels := CapturedOpaquePixels;

      Check(FullRangePixels > 0, 'full range was not rendered');
      Check(SingleRangePixels > 0, 'single note range was not rendered');
      Check(SingleRangePixels < FullRangePixels,
        'pitch range settings did not change the rendered pixels');

      // 大プリセットのボタンでローカル値と選択中オブジェクトを同時に更新する。
      FillChar(Edit, SizeOf(Edit), 0);
      Edit.GetFocusObject := GetMockFocusObject;
      Edit.SetObjectItemValue := SetMockObjectItemValue;
      CapturedPresetLength := '';
      CapturedPresetThickness := '';
      CapturedPresetNoteThickness := '';
      PFILTER_ITEM_SELECT(Items^[23])^.Value := 2;
      PFILTER_ITEM_BUTTON(Items^[24])^.Callback(@Edit);
      Check(PFILTER_ITEM_TRACK(Items^[7])^.Value = 120,
        'large preset local key length mismatch');
      Check(PFILTER_ITEM_TRACK(Items^[8])^.Value = 40,
        'large preset local key thickness mismatch');
      Check(PFILTER_ITEM_TRACK(Items^[9])^.Value = 80,
        'large preset local note thickness mismatch');
      Check((CapturedPresetLength = '120') and
        (CapturedPresetThickness = '40') and
        (CapturedPresetNoteThickness = '80'),
        'large preset object values mismatch');
      Writeln(Format('PASS full=%d single=%d',
        [FullRangePixels, SingleRangePixels]));
    finally
      UninitializePlugin;
    end;
  finally
    FreeLibrary(ModuleHandle);
    if TFile.Exists(MidiFileName) then
      TFile.Delete(MidiFileName);
  end;
end.

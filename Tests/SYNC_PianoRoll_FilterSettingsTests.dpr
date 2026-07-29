program SYNC_PianoRoll_FilterSettingsTests;

// 実Filter DLLの音域設定とサイズプリセットが描画項目へ反映されることを検証する。

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
  TItemArray = array[0..37] of Pointer;
  PItemArray = ^TItemArray;

var
  CapturedOpaquePixels: Integer;
  CapturedPolyCalls: Integer;
  CapturedPresetLength: string;
  CapturedPresetNoteThickness: string;
  CapturedPresetThickness: string;
  CapturedTrackPixels: Integer;

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
  CapturedTrackPixels := 0;
  for I := 0 to Width * Height - 1 do
  begin
    if PPixelArray(Buffer)^[I].A <> 0 then
      Inc(CapturedOpaquePixels);
    if (PPixelArray(Buffer)^[I].R = 80) and
      (PPixelArray(Buffer)^[I].G = 210) and
      (PPixelArray(Buffer)^[I].B = 255) and
      (PPixelArray(Buffer)^[I].A = 255) then
      Inc(CapturedTrackPixels);
  end;
end;

function CapturePoly(VertexType: Integer; VertexList: Pointer;
  VertexNum: Integer; Resource: LPCWSTR): Byte; cdecl;
begin
  Inc(CapturedPolyCalls);
  Result := 1;
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
    $00, $90, $3D, $64,
    $83, $60, $80, $3D, $00,
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
      Check(PFILTER_ITEM_SELECT(Items^[5])^.Value = 0,
        'piano keyboard must be the default');
      Check(PFILTER_ITEM_TRACK(Items^[9])^.Value = 30.0,
        '3D display time default mismatch');
      Check((PFILTER_ITEM_TRACK(Items^[18])^.Value = 0) and
        (PFILTER_ITEM_TRACK(Items^[19])^.Value = 0) and
        (PFILTER_ITEM_TRACK(Items^[20])^.Value = 0),
        '3D thickness defaults must be flat');

      FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
      FillChar(Video, SizeOf(Video), 0);
      ObjectInfo.ID := 901;
      ObjectInfo.EffectID := 902;
      ObjectInfo.Width := 640;
      ObjectInfo.Height := 360;
      Video.Object_ := @ObjectInfo;
      Video.SetImageData := CaptureImage;
      Video.DrawPoly := CapturePoly;

      PFILTER_ITEM_TRACK(Items^[12])^.Value := 128;
      PFILTER_ITEM_TRACK(Items^[13])^.Value := 64;
      CapturedOpaquePixels := 0;
      Table^.Func_Proc_Video(@Video);
      FullRangePixels := CapturedOpaquePixels;

      PFILTER_ITEM_TRACK(Items^[12])^.Value := 1;
      PFILTER_ITEM_TRACK(Items^[13])^.Value := 61;
      CapturedOpaquePixels := 0;
      Table^.Func_Proc_Video(@Video);
      SingleRangePixels := CapturedOpaquePixels;

      Check(FullRangePixels > 0, 'full range was not rendered');
      Check(SingleRangePixels > 0, 'single note range was not rendered');
      Check(SingleRangePixels < FullRangePixels,
        'pitch range settings did not change the rendered pixels');

      // 基準音域外のノートは追従なしでは隠れ、両追従方式では表示される。
      PFILTER_ITEM_TRACK(Items^[12])^.Value := 12;
      PFILTER_ITEM_TRACK(Items^[13])^.Value := 0;
      PFILTER_ITEM_SELECT(Items^[14])^.Value := 0;
      Table^.Func_Proc_Video(@Video);
      Check(CapturedTrackPixels = 0,
        'none follow unexpectedly moved the pitch range');
      PFILTER_ITEM_SELECT(Items^[14])^.Value := 1;
      Table^.Func_Proc_Video(@Video);
      Check(CapturedTrackPixels > 0,
        'always follow did not move the pitch range');
      PFILTER_ITEM_SELECT(Items^[14])^.Value := 2;
      Table^.Func_Proc_Video(@Video);
      Check(CapturedTrackPixels > 0,
        'overflow follow did not move the pitch range');

      // 実DLLでもハープへ切り替えると半音ノートを描画しない。
      PFILTER_ITEM_SELECT(Items^[5])^.Value := 1;
      PFILTER_ITEM_TRACK(Items^[12])^.Value := 1;
      PFILTER_ITEM_TRACK(Items^[13])^.Value := 61;
      PFILTER_ITEM_SELECT(Items^[14])^.Value := 0;
      Table^.Func_Proc_Video(@Video);
      Check(CapturedTrackPixels = 0,
        'harp keyboard rendered an accidental note');

      // 3D Type1は設定された縦横それぞれの専用DrawPoly経路を使う。
      PFILTER_ITEM_SELECT(Items^[5])^.Value := 0;
      PFILTER_ITEM_SELECT(Items^[2])^.Value := 1;
      PFILTER_ITEM_SELECT(Items^[4])^.Value := 0;
      CapturedPolyCalls := 0;
      Table^.Func_Proc_Video(@Video);
      Check(CapturedPolyCalls > 0,
        '3D vertical Type1 did not use DrawPoly');
      PFILTER_ITEM_SELECT(Items^[4])^.Value := 1;
      CapturedPolyCalls := 0;
      Table^.Func_Proc_Video(@Video);
      Check(CapturedPolyCalls > 0,
        '3D horizontal Type1 did not use DrawPoly');

      // 大プリセットのボタンでローカル値と選択中オブジェクトを同時に更新する。
      FillChar(Edit, SizeOf(Edit), 0);
      Edit.GetFocusObject := GetMockFocusObject;
      Edit.SetObjectItemValue := SetMockObjectItemValue;
      CapturedPresetLength := '';
      CapturedPresetThickness := '';
      CapturedPresetNoteThickness := '';
      PFILTER_ITEM_SELECT(Items^[6])^.Value := 2;
      PFILTER_ITEM_BUTTON(Items^[7])^.Callback(@Edit);
      Check(PFILTER_ITEM_TRACK(Items^[15])^.Value = 180,
        'large preset local key length mismatch');
      Check(PFILTER_ITEM_TRACK(Items^[16])^.Value = 60,
        'large preset local key thickness mismatch');
      Check(PFILTER_ITEM_TRACK(Items^[17])^.Value = 80,
        'large preset local note thickness mismatch');
      Check((CapturedPresetLength = '180') and
        (CapturedPresetThickness = '60') and
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

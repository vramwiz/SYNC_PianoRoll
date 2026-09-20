unit SYNC_PianoRoll_SizePreset;

// サイズ適用ボタンから、選択中のピアノロールへ連動した鍵盤寸法を書き戻す。
interface
uses AviUtl2FilterTypes;
procedure ApplySizePresetButton(Edit: PEDIT_SECTION); cdecl;
implementation
uses SYNC_PianoRoll_MediaItems;
procedure ApplySizePresetToLocalItems(Preset: Integer);
begin
  // 現在の中を基準寸法とし、大では時間方向と音階方向を1.5倍にする。
  case Preset of
    SIZE_PRESET_LARGE:
      begin
        Items.KeyLengthItem.Value := 180;
        Items.KeyThicknessItem.Value := 60;
        Items.NoteThicknessItem.Value := 80;
      end;
  else
    Items.KeyLengthItem.Value := 120;
    Items.KeyThicknessItem.Value := 40;
    Items.NoteThicknessItem.Value := 80;
  end;
end;

function SetSizePresetObjectItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  Item: PWideChar; const Value: UTF8String): Boolean;
begin
  Result := False;
  if (Edit = nil) or (Obj = nil) or not Assigned(Edit^.SetObjectItemValue) then
    Exit;

  // 登録名を指定し、選択中のピアノロールだけを書き換える。
  Result := Edit^.SetObjectItemValue(Obj, PIANO_ROLL_NAME,
    Item, PAnsiChar(Value)) <> 0;
end;

procedure ApplySizePresetToObject(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  Preset: Integer);
begin
  case Preset of
    SIZE_PRESET_LARGE:
      begin
        SetSizePresetObjectItem(Edit, Obj, '鍵盤の長さ', UTF8String('180'));
        SetSizePresetObjectItem(Edit, Obj, '鍵盤の太さ', UTF8String('60'));
      end;
  else
    SetSizePresetObjectItem(Edit, Obj, '鍵盤の長さ', UTF8String('120'));
    SetSizePresetObjectItem(Edit, Obj, '鍵盤の太さ', UTF8String('40'));
  end;
  SetSizePresetObjectItem(Edit, Obj, 'ノート太さ (%)', UTF8String('80'));
end;

procedure ApplySizePresetButton(Edit: PEDIT_SECTION); cdecl;
var
  Obj: OBJECT_HANDLE;
  Preset: Integer;
begin
  if Edit = nil then
    Exit;

  Preset := Items.SizePresetItem.Value;
  ApplySizePresetToLocalItems(Preset);
  if not Assigned(Edit^.GetFocusObject) then
    Exit;
  Obj := Edit^.GetFocusObject;
  if Obj = nil then
    Exit;
  ApplySizePresetToObject(Edit, Obj, Preset);
end;


end.

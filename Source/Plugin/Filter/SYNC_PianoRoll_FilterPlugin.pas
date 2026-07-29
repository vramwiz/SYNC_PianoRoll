unit SYNC_PianoRoll_FilterPlugin;

// Filter登録、設定値取得、共通処理と表示タイプへの委譲を担当する。

interface

uses
  AviUtl2FilterTypes;

function GetPianoRollFilterTable: PFILTER_PLUGIN_TABLE;
procedure InitializePianoRollFilter;
procedure FinalizePianoRollFilter;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_PianoRoll_Colors,
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_HorizontalDisplay,
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_PianoKeys,
  SYNC_PianoRoll_Renderer,
  SYNC_PianoRoll_Time,
  SYNC_PianoRoll_VerticalDisplay;

const
  SIZE_PRESET_MEDIUM = 1;
  SIZE_PRESET_LARGE = 2;

var
  BeatLineColorItem: TFILTER_ITEM_COLOR;
  BeatsPerMeasureItem: TFILTER_ITEM_TRACK;
  BlackKeyColorItem: TFILTER_ITEM_COLOR;
  BlackLaneColorItem: TFILTER_ITEM_COLOR;
  CenterNoteItem: TFILTER_ITEM_TRACK;
  DisplayTypeItem: TFILTER_ITEM_SELECT;
  DisplayTypeList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  DisplayTimeItem: TFILTER_ITEM_TRACK;
  GradientColor1Item: TFILTER_ITEM_COLOR;
  GradientColor2Item: TFILTER_ITEM_COLOR;
  HorizontalPianoRollDisplay: IPianoRollDisplay;
  KeyLengthItem: TFILTER_ITEM_TRACK;
  KeyThicknessItem: TFILTER_ITEM_TRACK;
  KeyboardTypeItem: TFILTER_ITEM_SELECT;
  KeyboardTypeList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  MeasureLineColorItem: TFILTER_ITEM_COLOR;
  MusicFileItem: TFILTER_ITEM_FILE;
  NoteDepthItem: TFILTER_ITEM_SELECT;
  NoteDepthList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  NoteThicknessItem: TFILTER_ITEM_TRACK;
  PitchFollowItem: TFILTER_ITEM_SELECT;
  PitchFollowList: array[0..3] of TFILTER_ITEM_SELECT_ITEM;
  VerticalPianoRollDisplay: IPianoRollDisplay;
  ShowBeatLinesItem: TFILTER_ITEM_SELECT;
  ShowLanesItem: TFILTER_ITEM_SELECT;
  ShowSelectList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  SizePresetButton: TFILTER_ITEM_BUTTON;
  SizePresetItem: TFILTER_ITEM_SELECT;
  SizePresetList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  SingleTrackColorItem: TFILTER_ITEM_COLOR;
  StrikeLineColorItem: TFILTER_ITEM_COLOR;
  StrikePositionItem: TFILTER_ITEM_TRACK;
  TimeShiftItem: TFILTER_ITEM_TRACK;
  TrackColorModeItem: TFILTER_ITEM_SELECT;
  TrackColorModeList: array[0..15] of TFILTER_ITEM_SELECT_ITEM;
  VisibleNoteCountItem: TFILTER_ITEM_TRACK;
  WhiteKeyColorItem: TFILTER_ITEM_COLOR;
  WhiteLaneColorItem: TFILTER_ITEM_COLOR;
  PluginItems: array[0..29] of Pointer;

function GetFilterColor(const Item: TFILTER_ITEM_COLOR;
  Alpha: Byte): TPianoRollColor;
begin
  Result := PianoRollColor(Item.R, Item.G, Item.B, Alpha);
end;

procedure InitializeColorItem(var Item: TFILTER_ITEM_COLOR;
  Name: PWideChar; const Color: TPianoRollColor);
begin
  Item.ItemType := 'color';
  Item.Name := Name;
  Item.R := Color.R;
  Item.G := Color.G;
  Item.B := Color.B;
  Item.X := 0;
end;

procedure ApplySizePresetToLocalItems(Preset: Integer);
begin
  // 現在の中を基準寸法とし、大では時間方向と音階方向を1.5倍にする。
  case Preset of
    SIZE_PRESET_LARGE:
      begin
        KeyLengthItem.Value := 180;
        KeyThicknessItem.Value := 60;
        NoteThicknessItem.Value := 80;
      end;
  else
    KeyLengthItem.Value := 120;
    KeyThicknessItem.Value := 40;
    NoteThicknessItem.Value := 80;
  end;
end;

function SetSizePresetObjectItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  Item: PWideChar; const Value: UTF8String): Boolean;
begin
  Result := False;
  if (Edit = nil) or (Obj = nil) or not Assigned(Edit^.SetObjectItemValue) then
    Exit;

  // 登録名を指定し、選択中のピアノロールFilterだけを書き換える。
  Result := Edit^.SetObjectItemValue(Obj, 'SYNC_ピアノロール_Filter',
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

  Preset := SizePresetItem.Value;
  ApplySizePresetToLocalItems(Preset);
  if not Assigned(Edit^.GetFocusObject) then
    Exit;
  Obj := Edit^.GetFocusObject;
  if Obj = nil then
    Exit;
  ApplySizePresetToObject(Edit, Obj, Preset);
end;

procedure BuildDisplaySettings(out Settings: TPianoRollDisplaySettings);
begin
  SetDefaultPianoRollDisplaySettings(Settings);
  Settings.DisplayTime := EnsureRange(DisplayTimeItem.Value, 0.1, 60.0);
  Settings.StrikePosition := EnsureRange(
    StrikePositionItem.Value / 100.0, 0.0, 1.0);
  Settings.TimeShift := EnsureRange(TimeShiftItem.Value, -60.0, 60.0);
  Settings.VisibleNoteCount := EnsureRange(
    Round(VisibleNoteCountItem.Value), 1, 128);
  Settings.CenterNote := EnsureRange(Round(CenterNoteItem.Value), 0, 127);
  case PitchFollowItem.Value of
    Ord(ppfmAlways):
      Settings.PitchFollowMode := ppfmAlways;
    Ord(ppfmOnOverflow):
      Settings.PitchFollowMode := ppfmOnOverflow;
  else
    // 未知値は基準音域を変えない既定動作へ戻す。
    Settings.PitchFollowMode := ppfmNone;
  end;
  if KeyboardTypeItem.Value = Ord(pktHarp7) then
    Settings.KeyboardType := pktHarp7
  else
    // 未知値は半音を欠落させない標準ピアノへ戻す。
    Settings.KeyboardType := pktPiano;
  Settings.KeyLength := EnsureRange(KeyLengthItem.Value, 0.0, 1000.0);
  Settings.KeyThickness := EnsureRange(
    KeyThicknessItem.Value, 1.0, 200.0);
  Settings.NoteThickness := EnsureRange(
    NoteThicknessItem.Value / 100.0, 0.05, 1.0);
  Settings.NoteDepthEnabled := NoteDepthItem.Value <> 0;
  Settings.ShowLanes := ShowLanesItem.Value <> 0;
  Settings.ShowBeatLines := ShowBeatLinesItem.Value <> 0;
  Settings.BeatsPerMeasure := EnsureRange(
    Round(BeatsPerMeasureItem.Value), 1, 32);
  if InRange(TrackColorModeItem.Value,
    Ord(Low(TPianoRollTrackColorMode)),
    Ord(High(TPianoRollTrackColorMode))) then
    Settings.TrackColorMode :=
      TPianoRollTrackColorMode(TrackColorModeItem.Value)
  else
    Settings.TrackColorMode := ptcmSingleColor;
  Settings.SingleTrackColor := GetFilterColor(SingleTrackColorItem,
    Settings.SingleTrackColor.A);
  Settings.GradientColor1 := GetFilterColor(GradientColor1Item,
    Settings.GradientColor1.A);
  Settings.GradientColor2 := GetFilterColor(GradientColor2Item,
    Settings.GradientColor2.A);
  Settings.Palette.WhiteKey := GetFilterColor(WhiteKeyColorItem,
    Settings.Palette.WhiteKey.A);
  Settings.Palette.BlackKey := GetFilterColor(BlackKeyColorItem,
    Settings.Palette.BlackKey.A);
  Settings.Palette.WhiteLane := GetFilterColor(WhiteLaneColorItem,
    Settings.Palette.WhiteLane.A);
  Settings.Palette.BlackLane := GetFilterColor(BlackLaneColorItem,
    Settings.Palette.BlackLane.A);
  Settings.Palette.BeatLine := GetFilterColor(BeatLineColorItem,
    Settings.Palette.BeatLine.A);
  Settings.Palette.MeasureLine := GetFilterColor(MeasureLineColorItem,
    Settings.Palette.MeasureLine.A);
  Settings.Palette.StrikeLine := GetFilterColor(StrikeLineColorItem,
    Settings.Palette.StrikeLine.A);
end;

function ResolvePianoRollDisplay: IPianoRollDisplay;
begin
  // 未知の値も縦表示へ戻し、将来の表示タイプ追加時も安全に描画する。
  case DisplayTypeItem.Value of
    Ord(pdtHorizontal):
      Result := HorizontalPianoRollDisplay;
    Ord(pdtVertical):
      Result := VerticalPianoRollDisplay;
  else
    Result := VerticalPianoRollDisplay;
  end;
end;

function PianoRollProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  DisplaySettings: TPianoRollDisplaySettings;
  MusicData: IPianoRollMusicData;
  MusicFileName: string;
  TimeSeconds: Double;
begin
  try
    // 単体配置はローカル時刻、Input＋Filterは入力開始時間込みの時刻を使う。
    if TryGetPianoRollTimeSeconds(Video, TimeSeconds) then
    begin
      MusicFileName := Trim(string(MusicFileItem.Value));
      if MusicFileName <> '' then
        if TryGetPianoRollMusicData(MusicFileName, MusicData) then
        begin
          BuildDisplaySettings(DisplaySettings);
          RenderPianoRoll(Video, MusicData, TimeSeconds,
            ResolvePianoRollDisplay, DisplaySettings);
        end;
    end;
  except
    // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
  end;
  Result := 1;
end;

var
  Plugin: TFILTER_PLUGIN_TABLE = (
    // 映像生成を登録し、単体配置とInputベースへの追加で同じ描画処理を使う。
    Flag: FILTER_FLAG_VIDEO;
    Name: 'SYNC_ピアノロール_Filter';
    Label_: 'SYNC';
    Information: '音楽データに同期するピアノロール描画フィルター';
    Items: nil;
    Func_Proc_Video: PianoRollProcVideo;
    Func_Proc_Audio: nil
  );

function GetPianoRollFilterTable: PFILTER_PLUGIN_TABLE;
var
  DefaultPalette: TPianoRollPalette;
begin
  if Plugin.Items = nil then
  begin
    SetDefaultPianoRollPalette(DefaultPalette);
    MusicFileItem.ItemType := 'file';
    MusicFileItem.Name := '音楽ファイル';
    MusicFileItem.Value := '';
    MusicFileItem.FileFilter :=
      '音楽ファイル (*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz)'#0 +
      '*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz'#0#0;

    DisplayTimeItem.ItemType := 'track';
    DisplayTimeItem.Name := '表示時間 (秒)';
    DisplayTimeItem.Value := 4.0;
    DisplayTimeItem.S := 0.1;
    DisplayTimeItem.E := 60.0;
    DisplayTimeItem.Step := 0.1;

    StrikePositionItem.ItemType := 'track';
    StrikePositionItem.Name := '発音位置 (%)';
    StrikePositionItem.Value := 80.0;
    StrikePositionItem.S := 0.0;
    StrikePositionItem.E := 100.0;
    StrikePositionItem.Step := 1.0;

    TimeShiftItem.ItemType := 'track';
    TimeShiftItem.Name := 'ずらし (秒)';
    TimeShiftItem.Value := 0.0;
    TimeShiftItem.S := -60.0;
    TimeShiftItem.E := 60.0;
    TimeShiftItem.Step := 0.01;

    VisibleNoteCountItem.ItemType := 'track';
    VisibleNoteCountItem.Name := '表示音階数';
    // MIDI全域の半分を初期表示し、中央ノートで音域を調整できる余地を残す。
    VisibleNoteCountItem.Value := 64;
    VisibleNoteCountItem.S := 1;
    VisibleNoteCountItem.E := 128;
    VisibleNoteCountItem.Step := 1;

    CenterNoteItem.ItemType := 'track';
    CenterNoteItem.Name := '中央ノート';
    CenterNoteItem.Value := 64;
    CenterNoteItem.S := 0;
    CenterNoteItem.E := 127;
    CenterNoteItem.Step := 1;

    PitchFollowList[0].Name := '追従しない';
    PitchFollowList[0].Value := Ord(ppfmNone);
    PitchFollowList[1].Name := '常に追従';
    PitchFollowList[1].Value := Ord(ppfmAlways);
    PitchFollowList[2].Name := 'はみ出したとき追従';
    PitchFollowList[2].Value := Ord(ppfmOnOverflow);
    PitchFollowList[3].Name := nil;
    PitchFollowList[3].Value := 0;
    PitchFollowItem.ItemType := 'select';
    PitchFollowItem.Name := '音域追従';
    PitchFollowItem.Value := Ord(ppfmNone);
    PitchFollowItem.List := @PitchFollowList[0];

    KeyLengthItem.ItemType := 'track';
    KeyLengthItem.Name := '鍵盤の長さ';
    KeyLengthItem.Value := 120;
    KeyLengthItem.S := 0;
    KeyLengthItem.E := 1000;
    KeyLengthItem.Step := 1;

    KeyThicknessItem.ItemType := 'track';
    KeyThicknessItem.Name := '鍵盤の太さ';
    KeyThicknessItem.Value := 40;
    KeyThicknessItem.S := 1;
    KeyThicknessItem.E := 200;
    KeyThicknessItem.Step := 1;

    NoteThicknessItem.ItemType := 'track';
    NoteThicknessItem.Name := 'ノート太さ (%)';
    NoteThicknessItem.Value := 80;
    NoteThicknessItem.S := 5;
    NoteThicknessItem.E := 100;
    NoteThicknessItem.Step := 1;

    NoteDepthList[0].Name := '平面';
    NoteDepthList[0].Value := 0;
    NoteDepthList[1].Name := '立体';
    NoteDepthList[1].Value := 1;
    NoteDepthList[2].Name := nil;
    NoteDepthList[2].Value := 0;
    NoteDepthItem.ItemType := 'select';
    NoteDepthItem.Name := 'ノート立体表示';
    NoteDepthItem.Value := 1;
    NoteDepthItem.List := @NoteDepthList[0];

    ShowSelectList[0].Name := '非表示';
    ShowSelectList[0].Value := 0;
    ShowSelectList[1].Name := '表示';
    ShowSelectList[1].Value := 1;
    ShowSelectList[2].Name := nil;
    ShowSelectList[2].Value := 0;

    ShowLanesItem.ItemType := 'select';
    ShowLanesItem.Name := 'レーン表示';
    ShowLanesItem.Value := 1;
    ShowLanesItem.List := @ShowSelectList[0];

    ShowBeatLinesItem.ItemType := 'select';
    ShowBeatLinesItem.Name := '拍線表示';
    ShowBeatLinesItem.Value := 1;
    ShowBeatLinesItem.List := @ShowSelectList[0];

    BeatsPerMeasureItem.ItemType := 'track';
    BeatsPerMeasureItem.Name := '1小節の拍数';
    BeatsPerMeasureItem.Value := 4;
    BeatsPerMeasureItem.S := 1;
    BeatsPerMeasureItem.E := 32;
    BeatsPerMeasureItem.Step := 1;

    InitializeColorItem(WhiteKeyColorItem, '白鍵色',
      DefaultPalette.WhiteKey);
    InitializeColorItem(BlackKeyColorItem, '黒鍵色',
      DefaultPalette.BlackKey);
    InitializeColorItem(WhiteLaneColorItem, '白鍵レーン色',
      DefaultPalette.WhiteLane);
    InitializeColorItem(BlackLaneColorItem, '黒鍵レーン色',
      DefaultPalette.BlackLane);
    InitializeColorItem(BeatLineColorItem, '拍線色',
      DefaultPalette.BeatLine);
    InitializeColorItem(MeasureLineColorItem, '小節線色',
      DefaultPalette.MeasureLine);
    InitializeColorItem(StrikeLineColorItem, '発音線色',
      DefaultPalette.StrikeLine);

    TrackColorModeList[0].Name := '単色';
    TrackColorModeList[0].Value := Ord(ptcmSingleColor);
    TrackColorModeList[1].Name := 'バリエーション1';
    TrackColorModeList[1].Value := Ord(ptcmVariation1);
    TrackColorModeList[2].Name := 'トラック：DOS';
    TrackColorModeList[2].Value := Ord(ptcmTrackDOS);
    TrackColorModeList[3].Name := 'トラック：虹';
    TrackColorModeList[3].Value := Ord(ptcmTrackRainbow);
    TrackColorModeList[4].Name := 'トラック：淡色';
    TrackColorModeList[4].Value := Ord(ptcmTrackSoft);
    TrackColorModeList[5].Name := 'トラック：暗色';
    TrackColorModeList[5].Value := Ord(ptcmTrackDark);
    TrackColorModeList[6].Name := '音階：DOS';
    TrackColorModeList[6].Value := Ord(ptcmKeyDOS);
    TrackColorModeList[7].Name := '音階：虹';
    TrackColorModeList[7].Value := Ord(ptcmKeyRainbow);
    TrackColorModeList[8].Name := '音階：淡色';
    TrackColorModeList[8].Value := Ord(ptcmKeySoft);
    TrackColorModeList[9].Name := '音階：暗色';
    TrackColorModeList[9].Value := Ord(ptcmKeyDark);
    TrackColorModeList[10].Name := 'ドレミ：虹';
    TrackColorModeList[10].Value := Ord(ptcmDoReMiRainbow);
    TrackColorModeList[11].Name := 'ドレミ：淡色';
    TrackColorModeList[11].Value := Ord(ptcmDoReMiSoft);
    TrackColorModeList[12].Name := 'ドレミ：暗色';
    TrackColorModeList[12].Value := Ord(ptcmDoReMiDark);
    TrackColorModeList[13].Name := 'グラデ色：RGB';
    TrackColorModeList[13].Value := Ord(ptcmGradientRGB);
    TrackColorModeList[14].Name := 'グラデ色：HSV';
    TrackColorModeList[14].Value := Ord(ptcmGradientHSV);
    TrackColorModeList[15].Name := nil;
    TrackColorModeList[15].Value := 0;
    TrackColorModeItem.ItemType := 'select';
    TrackColorModeItem.Name := 'ノート配色';
    TrackColorModeItem.Value := Ord(ptcmSingleColor);
    TrackColorModeItem.List := @TrackColorModeList[0];
    InitializeColorItem(SingleTrackColorItem, 'ノート単色',
      DefaultPalette.TrackColors[0]);
    InitializeColorItem(GradientColor1Item, 'グラデ色1',
      PianoRollColor(255, 0, 0, 255));
    InitializeColorItem(GradientColor2Item, 'グラデ色2',
      PianoRollColor(0, 0, 255, 255));

    DisplayTypeList[0].Name := '縦';
    DisplayTypeList[0].Value := Ord(pdtVertical);
    DisplayTypeList[1].Name := '横';
    DisplayTypeList[1].Value := Ord(pdtHorizontal);
    DisplayTypeList[2].Name := nil;
    DisplayTypeList[2].Value := 0;
    DisplayTypeItem.ItemType := 'select';
    DisplayTypeItem.Name := '表示タイプ';
    DisplayTypeItem.Value := Ord(pdtVertical);
    DisplayTypeItem.List := @DisplayTypeList[0];

    KeyboardTypeList[0].Name := '標準ピアノ';
    KeyboardTypeList[0].Value := Ord(pktPiano);
    KeyboardTypeList[1].Name := 'ハープ（7音）';
    KeyboardTypeList[1].Value := Ord(pktHarp7);
    KeyboardTypeList[2].Name := nil;
    KeyboardTypeList[2].Value := 0;
    KeyboardTypeItem.ItemType := 'select';
    KeyboardTypeItem.Name := '鍵盤タイプ';
    KeyboardTypeItem.Value := Ord(pktPiano);
    KeyboardTypeItem.List := @KeyboardTypeList[0];

    SizePresetList[0].Name := '中';
    SizePresetList[0].Value := SIZE_PRESET_MEDIUM;
    SizePresetList[1].Name := '大';
    SizePresetList[1].Value := SIZE_PRESET_LARGE;
    SizePresetList[2].Name := nil;
    SizePresetList[2].Value := 0;
    SizePresetItem.ItemType := 'select';
    SizePresetItem.Name := 'サイズ';
    SizePresetItem.Value := SIZE_PRESET_MEDIUM;
    SizePresetItem.List := @SizePresetList[0];
    SizePresetButton.ItemType := 'button';
    SizePresetButton.Name := 'サイズ適用';
    SizePresetButton.Callback := ApplySizePresetButton;

    // AviUtl2はnil終端された項目ポインター配列を参照する。
    // 通常利用する基本設定を先頭へまとめ、以降に詳細設定を並べる。
    PluginItems[0] := @MusicFileItem;
    PluginItems[1] := @SizePresetItem;
    PluginItems[2] := @SizePresetButton;
    PluginItems[3] := @DisplayTypeItem;
    PluginItems[4] := @KeyboardTypeItem;
    PluginItems[5] := @DisplayTimeItem;
    PluginItems[6] := @StrikePositionItem;
    PluginItems[7] := @TimeShiftItem;
    PluginItems[8] := @VisibleNoteCountItem;
    PluginItems[9] := @CenterNoteItem;
    PluginItems[10] := @PitchFollowItem;
    PluginItems[11] := @KeyLengthItem;
    PluginItems[12] := @KeyThicknessItem;
    PluginItems[13] := @NoteThicknessItem;
    PluginItems[14] := @ShowLanesItem;
    PluginItems[15] := @ShowBeatLinesItem;
    PluginItems[16] := @BeatsPerMeasureItem;
    PluginItems[17] := @WhiteKeyColorItem;
    PluginItems[18] := @BlackKeyColorItem;
    PluginItems[19] := @WhiteLaneColorItem;
    PluginItems[20] := @BlackLaneColorItem;
    PluginItems[21] := @BeatLineColorItem;
    PluginItems[22] := @MeasureLineColorItem;
    PluginItems[23] := @StrikeLineColorItem;
    PluginItems[24] := @TrackColorModeItem;
    PluginItems[25] := @SingleTrackColorItem;
    PluginItems[26] := @NoteDepthItem;
    PluginItems[27] := @GradientColor1Item;
    PluginItems[28] := @GradientColor2Item;
    PluginItems[29] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializePianoRollFilter;
begin
  VerticalPianoRollDisplay := CreateVerticalPianoRollDisplay;
  HorizontalPianoRollDisplay := CreateHorizontalPianoRollDisplay;
  InitializePianoRollMusicCache;
  InitializePianoRollRenderer;
end;

procedure FinalizePianoRollFilter;
begin
  FinalizePianoRollRenderer;
  HorizontalPianoRollDisplay := nil;
  VerticalPianoRollDisplay := nil;
  FinalizePianoRollMusicCache;
end;

end.

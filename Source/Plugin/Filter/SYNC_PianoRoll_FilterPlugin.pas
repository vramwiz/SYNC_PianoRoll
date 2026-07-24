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
  SYNC_PianoRoll_ContextManager,
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_FrameShared,
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_Renderer,
  SYNC_PianoRoll_VerticalDisplay;

var
  AutoKeyRangeItem: TFILTER_ITEM_SELECT;
  AutoKeyRangeList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  BeatLineColorItem: TFILTER_ITEM_COLOR;
  BeatsPerMeasureItem: TFILTER_ITEM_TRACK;
  BlackKeyColorItem: TFILTER_ITEM_COLOR;
  BlackLaneColorItem: TFILTER_ITEM_COLOR;
  DisplayTimeItem: TFILTER_ITEM_TRACK;
  HighestKeyItem: TFILTER_ITEM_TRACK;
  KeyLengthItem: TFILTER_ITEM_TRACK;
  KeyThicknessItem: TFILTER_ITEM_TRACK;
  LowestKeyItem: TFILTER_ITEM_TRACK;
  MeasureLineColorItem: TFILTER_ITEM_COLOR;
  MusicFileItem: TFILTER_ITEM_FILE;
  NoteThicknessItem: TFILTER_ITEM_TRACK;
  PianoRollDisplay: IPianoRollDisplay;
  ShowBeatLinesItem: TFILTER_ITEM_SELECT;
  ShowLanesItem: TFILTER_ITEM_SELECT;
  ShowSelectList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  StrikeLineColorItem: TFILTER_ITEM_COLOR;
  StrikePositionItem: TFILTER_ITEM_TRACK;
  TimeShiftItem: TFILTER_ITEM_TRACK;
  WhiteKeyColorItem: TFILTER_ITEM_COLOR;
  WhiteLaneColorItem: TFILTER_ITEM_COLOR;
  PluginItems: array[0..20] of Pointer;

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

procedure BuildDisplaySettings(out Settings: TPianoRollDisplaySettings);
begin
  SetDefaultPianoRollDisplaySettings(Settings);
  Settings.DisplayTime := EnsureRange(DisplayTimeItem.Value, 0.1, 60.0);
  Settings.StrikePosition := EnsureRange(
    StrikePositionItem.Value / 100.0, 0.0, 1.0);
  Settings.TimeShift := EnsureRange(TimeShiftItem.Value, -60.0, 60.0);
  Settings.LowestKey := EnsureRange(Round(LowestKeyItem.Value), 0, 127);
  Settings.HighestKey := EnsureRange(Round(HighestKeyItem.Value), 0, 127);
  if Settings.HighestKey < Settings.LowestKey then
    Settings.HighestKey := Settings.LowestKey;
  Settings.AutoKeyRange := AutoKeyRangeItem.Value <> 0;
  Settings.KeyLength := EnsureRange(KeyLengthItem.Value, 0.0, 1000.0);
  Settings.KeyThickness := EnsureRange(
    KeyThicknessItem.Value, 1.0, 200.0);
  Settings.NoteThickness := EnsureRange(
    NoteThicknessItem.Value / 100.0, 0.05, 1.0);
  Settings.ShowLanes := ShowLanesItem.Value <> 0;
  Settings.ShowBeatLines := ShowBeatLinesItem.Value <> 0;
  Settings.BeatsPerMeasure := EnsureRange(
    Round(BeatsPerMeasureItem.Value), 1, 32);
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

function PianoRollProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  DisplaySettings: TPianoRollDisplaySettings;
  EffectiveState: TSyncPianoRollFrameState;
  MusicData: IPianoRollMusicData;
  MusicFileName: string;
  SharedState: TSyncPianoRollFrameState;
begin
  try
    // 描画実装前でも、オブジェクトごとの有効な絶対フレームを更新する。
    if TryReadPianoRollFrame(SharedState) then
      if ResolvePianoRollFrameState(Video, SharedState, EffectiveState) then
      begin
        MusicFileName := Trim(string(MusicFileItem.Value));
        if MusicFileName <> '' then
          if TryGetPianoRollMusicData(MusicFileName, MusicData) then
          begin
            BuildDisplaySettings(DisplaySettings);
            RenderPianoRoll(Video, MusicData, EffectiveState.TimeSeconds,
              PianoRollDisplay, DisplaySettings);
          end;
      end;
  except
    // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
  end;
  Result := 1;
end;

var
  Plugin: TFILTER_PLUGIN_TABLE = (
    Flag: FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER;
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

    LowestKeyItem.ItemType := 'track';
    LowestKeyItem.Name := '最低音';
    LowestKeyItem.Value := 0;
    LowestKeyItem.S := 0;
    LowestKeyItem.E := 127;
    LowestKeyItem.Step := 1;

    HighestKeyItem.ItemType := 'track';
    HighestKeyItem.Name := '最高音';
    HighestKeyItem.Value := 127;
    HighestKeyItem.S := 0;
    HighestKeyItem.E := 127;
    HighestKeyItem.Step := 1;

    AutoKeyRangeList[0].Name := '手動';
    AutoKeyRangeList[0].Value := 0;
    AutoKeyRangeList[1].Name := '自動';
    AutoKeyRangeList[1].Value := 1;
    AutoKeyRangeList[2].Name := nil;
    AutoKeyRangeList[2].Value := 0;
    AutoKeyRangeItem.ItemType := 'select';
    AutoKeyRangeItem.Name := '音域';
    AutoKeyRangeItem.Value := 0;
    AutoKeyRangeItem.List := @AutoKeyRangeList[0];

    KeyLengthItem.ItemType := 'track';
    KeyLengthItem.Name := '鍵盤の長さ';
    KeyLengthItem.Value := 60;
    KeyLengthItem.S := 0;
    KeyLengthItem.E := 1000;
    KeyLengthItem.Step := 1;

    KeyThicknessItem.ItemType := 'track';
    KeyThicknessItem.Name := '鍵盤の太さ';
    KeyThicknessItem.Value := 20;
    KeyThicknessItem.S := 1;
    KeyThicknessItem.E := 200;
    KeyThicknessItem.Step := 1;

    NoteThicknessItem.ItemType := 'track';
    NoteThicknessItem.Name := 'ノート太さ (%)';
    NoteThicknessItem.Value := 80;
    NoteThicknessItem.S := 5;
    NoteThicknessItem.E := 100;
    NoteThicknessItem.Step := 1;

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

    // AviUtl2はnil終端された項目ポインター配列を参照する。
    PluginItems[0] := @MusicFileItem;
    PluginItems[1] := @DisplayTimeItem;
    PluginItems[2] := @StrikePositionItem;
    PluginItems[3] := @TimeShiftItem;
    PluginItems[4] := @LowestKeyItem;
    PluginItems[5] := @HighestKeyItem;
    PluginItems[6] := @AutoKeyRangeItem;
    PluginItems[7] := @KeyLengthItem;
    PluginItems[8] := @KeyThicknessItem;
    PluginItems[9] := @NoteThicknessItem;
    PluginItems[10] := @ShowLanesItem;
    PluginItems[11] := @ShowBeatLinesItem;
    PluginItems[12] := @BeatsPerMeasureItem;
    PluginItems[13] := @WhiteKeyColorItem;
    PluginItems[14] := @BlackKeyColorItem;
    PluginItems[15] := @WhiteLaneColorItem;
    PluginItems[16] := @BlackLaneColorItem;
    PluginItems[17] := @BeatLineColorItem;
    PluginItems[18] := @MeasureLineColorItem;
    PluginItems[19] := @StrikeLineColorItem;
    PluginItems[20] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializePianoRollFilter;
begin
  PianoRollDisplay := CreateVerticalPianoRollDisplay;
  InitializePianoRollFrameShared;
  InitializePianoRollContexts;
  InitializePianoRollMusicCache;
  InitializePianoRollRenderer;
end;

procedure FinalizePianoRollFilter;
begin
  FinalizePianoRollRenderer;
  PianoRollDisplay := nil;
  FinalizePianoRollMusicCache;
  FinalizePianoRollContexts;
  FinalizePianoRollFrameShared;
end;

end.

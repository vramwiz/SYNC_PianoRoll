unit SYNC_PianoRoll_MediaItems;

// メディアオブジェクトの設定項目と選択肢を、ホストが参照し続けられる領域へ登録する。
interface
uses AviUtl2FilterTypes;
const
  PIANO_ROLL_NAME = 'ピアノロール';
  SIZE_PRESET_MEDIUM = 1;
  SIZE_PRESET_LARGE = 2;
type
  TPianoRollMediaItems = record
    BeatLineColorItem: TFILTER_ITEM_COLOR;
    BeatsPerMeasureItem: TFILTER_ITEM_TRACK;
    BlackKeyColorItem: TFILTER_ITEM_COLOR;
    BlackKey3DThicknessItem: TFILTER_ITEM_TRACK;
    BlackLaneColorItem: TFILTER_ITEM_COLOR;
    CenterNoteItem: TFILTER_ITEM_TRACK;
    DisplayCategoryItem: TFILTER_ITEM_SELECT;
    DisplayCategoryList: array[0..1] of TFILTER_ITEM_SELECT_ITEM;
    DisplayTimeItem: TFILTER_ITEM_TRACK;
    DisplayTime3DItem: TFILTER_ITEM_TRACK;
    GradientColor1Item: TFILTER_ITEM_COLOR;
    GradientColor2Item: TFILTER_ITEM_COLOR;
    KeyLengthItem: TFILTER_ITEM_TRACK;
    KeyThicknessItem: TFILTER_ITEM_TRACK;
    KeyboardTypeItem: TFILTER_ITEM_SELECT;
    KeyboardTypeList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
    MeasureLineColorItem: TFILTER_ITEM_COLOR;
    MusicFileItem: TFILTER_ITEM_FILE;
    NoteDepthItem: TFILTER_ITEM_SELECT;
    NoteDepthList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
    NoteThicknessItem: TFILTER_ITEM_TRACK;
    Note3DThicknessItem: TFILTER_ITEM_TRACK;
    NotePositionOffsetItem: TFILTER_ITEM_TRACK;
    PitchFollowItem: TFILTER_ITEM_SELECT;
    PitchFollowList: array[0..3] of TFILTER_ITEM_SELECT_ITEM;
    RadiusItem: TFILTER_ITEM_TRACK;
    OrientationItem: TFILTER_ITEM_SELECT;
    OrientationList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
    RenderDimensionItem: TFILTER_ITEM_SELECT;
    RenderDimensionList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
    StyleTypeItem: TFILTER_ITEM_SELECT;
    StyleTypeList: array[0..3] of TFILTER_ITEM_SELECT_ITEM;
    ShowBeatLinesItem: TFILTER_ITEM_SELECT;
    ShowLanesItem: TFILTER_ITEM_SELECT;
    ShowSelectList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
    SizePresetButton: TFILTER_ITEM_BUTTON;
    SizePresetItem: TFILTER_ITEM_SELECT;
    SizePresetList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
    SingleTrackColorItem: TFILTER_ITEM_COLOR;
    StrikeLineColorItem: TFILTER_ITEM_COLOR;
    StrikeEffectTypeItem: TFILTER_ITEM_SELECT;
    StrikeEffectTypeList: array[0..1] of TFILTER_ITEM_SELECT_ITEM;
    StrikePositionItem: TFILTER_ITEM_TRACK;
    TimeShiftItem: TFILTER_ITEM_TRACK;
    TrackColorModeItem: TFILTER_ITEM_SELECT;
    TrackColorModeList: array[0..15] of TFILTER_ITEM_SELECT_ITEM;
    VisibleNoteCountItem: TFILTER_ITEM_TRACK;
    WhiteKeyColorItem: TFILTER_ITEM_COLOR;
    WhiteKey3DThicknessItem: TFILTER_ITEM_TRACK;
    WhiteLaneColorItem: TFILTER_ITEM_COLOR;
    PluginItems: array[0..43] of Pointer;

    CanvasWidthItem, CanvasHeightItem, StartPositionItem, PlaybackRateItem: TFILTER_ITEM_TRACK;
  end;
var
  // Valueは描画コールバックの直前にAviUtl2が現在値へ更新する。
  Items: TPianoRollMediaItems;
procedure InitializePianoRollMediaItems;
implementation
uses SYNC_PianoRoll_Colors, SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_PianoKeys, SYNC_PianoRoll_SizePreset;
var Initialized: Boolean;
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


procedure InitializeTrackItem(var Item: TFILTER_ITEM_TRACK;
  Name: PWideChar; Value, Minimum, Maximum, Step: Double);
begin
  Item.ItemType := 'track';
  Item.Name := Name;
  Item.Value := Value;
  Item.S := Minimum;
  Item.E := Maximum;
  Item.Step := Step;
end;

procedure InitializePianoRollMediaItems;
var DefaultPalette: TPianoRollPalette;
begin
  // 再取得でユーザーの設定値を初期値へ戻さない。
  if Initialized then Exit;
  SetDefaultPianoRollPalette(DefaultPalette);
  Items.MusicFileItem.ItemType := 'file';
  Items.MusicFileItem.Name := '音楽ファイル';
  Items.MusicFileItem.Value := '';
  Items.MusicFileItem.FileFilter :=
    '音楽ファイル (*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz)'#0 +
    '*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz'#0#0;

  InitializeTrackItem(Items.DisplayTimeItem, '表示時間 (秒)', 4.0, 0.1, 60.0, 0.1);

  InitializeTrackItem(Items.DisplayTime3DItem, '表示時間 3D (秒)', 30.0, 0.1, 600.0, 0.1);

  InitializeTrackItem(Items.StrikePositionItem, '発音位置 (%)', 80.0, 0.0, 100.0, 1.0);

  InitializeTrackItem(Items.TimeShiftItem, 'ずらし (秒)', 0.0, -60.0, 60.0, 0.01);

  Items.VisibleNoteCountItem.ItemType := 'track';
  Items.VisibleNoteCountItem.Name := '表示音階数';
  // MIDI全域の半分を初期表示し、中央ノートで音域を調整できる余地を残す。
  Items.VisibleNoteCountItem.Value := 64;
  Items.VisibleNoteCountItem.S := 1;
  Items.VisibleNoteCountItem.E := 128;
  Items.VisibleNoteCountItem.Step := 1;

  InitializeTrackItem(Items.CenterNoteItem, '中央ノート', 64, 0, 127, 1);

  Items.PitchFollowList[0].Name := '追従しない';
  Items.PitchFollowList[0].Value := Ord(ppfmNone);
  Items.PitchFollowList[1].Name := '常に追従';
  Items.PitchFollowList[1].Value := Ord(ppfmAlways);
  Items.PitchFollowList[2].Name := 'はみ出したとき追従';
  Items.PitchFollowList[2].Value := Ord(ppfmOnOverflow);
  Items.PitchFollowList[3].Name := nil;
  Items.PitchFollowList[3].Value := 0;
  Items.PitchFollowItem.ItemType := 'select';
  Items.PitchFollowItem.Name := '音域追従';
  Items.PitchFollowItem.Value := Ord(ppfmNone);
  Items.PitchFollowItem.List := @Items.PitchFollowList[0];

  InitializeTrackItem(Items.KeyLengthItem, '鍵盤の長さ', 120, 0, 1000, 1);

  InitializeTrackItem(Items.KeyThicknessItem, '鍵盤の太さ', 40, 1, 200, 1);

  InitializeTrackItem(Items.NoteThicknessItem, 'ノート太さ (%)', 80, 5, 100, 1);

  InitializeTrackItem(Items.WhiteKey3DThicknessItem, '白鍵3D厚み', 30, 0, 500, 1);

  InitializeTrackItem(Items.BlackKey3DThicknessItem, '黒鍵3D厚み', 20, 0, 500, 1);

  InitializeTrackItem(Items.Note3DThicknessItem, 'ノート3D厚み', 20, 0, 500, 1);

  InitializeTrackItem(Items.NotePositionOffsetItem, 'ノート位置オフセット', 0, -500, 500, 1);

  Items.RadiusItem.ItemType := 'track';
  Items.RadiusItem.Name := '半径';
  // 0は短辺と鍵盤寸法から外周が画面内へ収まる値を自動計算する。
  Items.RadiusItem.Value := 0;
  Items.RadiusItem.S := 0;
  Items.RadiusItem.E := 5000;
  Items.RadiusItem.Step := 1;

  Items.NoteDepthList[0].Name := '平面';
  Items.NoteDepthList[0].Value := 0;
  Items.NoteDepthList[1].Name := '立体';
  Items.NoteDepthList[1].Value := 1;
  Items.NoteDepthList[2].Name := nil;
  Items.NoteDepthList[2].Value := 0;
  Items.NoteDepthItem.ItemType := 'select';
  Items.NoteDepthItem.Name := 'ノート立体表示';
  Items.NoteDepthItem.Value := 1;
  Items.NoteDepthItem.List := @Items.NoteDepthList[0];

  Items.ShowSelectList[0].Name := '非表示';
  Items.ShowSelectList[0].Value := 0;
  Items.ShowSelectList[1].Name := '表示';
  Items.ShowSelectList[1].Value := 1;
  Items.ShowSelectList[2].Name := nil;
  Items.ShowSelectList[2].Value := 0;

  Items.ShowLanesItem.ItemType := 'select';
  Items.ShowLanesItem.Name := 'レーン表示';
  Items.ShowLanesItem.Value := 1;
  Items.ShowLanesItem.List := @Items.ShowSelectList[0];

  Items.ShowBeatLinesItem.ItemType := 'select';
  Items.ShowBeatLinesItem.Name := '拍線表示';
  Items.ShowBeatLinesItem.Value := 1;
  Items.ShowBeatLinesItem.List := @Items.ShowSelectList[0];

  InitializeTrackItem(Items.BeatsPerMeasureItem, '1小節の拍数', 4, 1, 32, 1);

  InitializeColorItem(Items.WhiteKeyColorItem, '白鍵色',
    DefaultPalette.WhiteKey);
  InitializeColorItem(Items.BlackKeyColorItem, '黒鍵色',
    DefaultPalette.BlackKey);
  InitializeColorItem(Items.WhiteLaneColorItem, '白鍵レーン色',
    DefaultPalette.WhiteLane);
  InitializeColorItem(Items.BlackLaneColorItem, '黒鍵レーン色',
    DefaultPalette.BlackLane);
  InitializeColorItem(Items.BeatLineColorItem, '拍線色',
    DefaultPalette.BeatLine);
  InitializeColorItem(Items.MeasureLineColorItem, '小節線色',
    DefaultPalette.MeasureLine);
  InitializeColorItem(Items.StrikeLineColorItem, '発音線色',
    DefaultPalette.StrikeLine);

  Items.TrackColorModeList[0].Name := '単色';
  Items.TrackColorModeList[0].Value := Ord(ptcmSingleColor);
  Items.TrackColorModeList[1].Name := 'バリエーション1';
  Items.TrackColorModeList[1].Value := Ord(ptcmVariation1);
  Items.TrackColorModeList[2].Name := 'トラック：DOS';
  Items.TrackColorModeList[2].Value := Ord(ptcmTrackDOS);
  Items.TrackColorModeList[3].Name := 'トラック：虹';
  Items.TrackColorModeList[3].Value := Ord(ptcmTrackRainbow);
  Items.TrackColorModeList[4].Name := 'トラック：淡色';
  Items.TrackColorModeList[4].Value := Ord(ptcmTrackSoft);
  Items.TrackColorModeList[5].Name := 'トラック：暗色';
  Items.TrackColorModeList[5].Value := Ord(ptcmTrackDark);
  Items.TrackColorModeList[6].Name := '音階：DOS';
  Items.TrackColorModeList[6].Value := Ord(ptcmKeyDOS);
  Items.TrackColorModeList[7].Name := '音階：虹';
  Items.TrackColorModeList[7].Value := Ord(ptcmKeyRainbow);
  Items.TrackColorModeList[8].Name := '音階：淡色';
  Items.TrackColorModeList[8].Value := Ord(ptcmKeySoft);
  Items.TrackColorModeList[9].Name := '音階：暗色';
  Items.TrackColorModeList[9].Value := Ord(ptcmKeyDark);
  Items.TrackColorModeList[10].Name := 'ドレミ：虹';
  Items.TrackColorModeList[10].Value := Ord(ptcmDoReMiRainbow);
  Items.TrackColorModeList[11].Name := 'ドレミ：淡色';
  Items.TrackColorModeList[11].Value := Ord(ptcmDoReMiSoft);
  Items.TrackColorModeList[12].Name := 'ドレミ：暗色';
  Items.TrackColorModeList[12].Value := Ord(ptcmDoReMiDark);
  Items.TrackColorModeList[13].Name := 'グラデ色：RGB';
  Items.TrackColorModeList[13].Value := Ord(ptcmGradientRGB);
  Items.TrackColorModeList[14].Name := 'グラデ色：HSV';
  Items.TrackColorModeList[14].Value := Ord(ptcmGradientHSV);
  Items.TrackColorModeList[15].Name := nil;
  Items.TrackColorModeList[15].Value := 0;
  Items.TrackColorModeItem.ItemType := 'select';
  Items.TrackColorModeItem.Name := 'ノート配色';
  Items.TrackColorModeItem.Value := Ord(ptcmSingleColor);
  Items.TrackColorModeItem.List := @Items.TrackColorModeList[0];
  InitializeColorItem(Items.SingleTrackColorItem, 'ノート単色',
    DefaultPalette.TrackColors[0]);
  InitializeColorItem(Items.GradientColor1Item, 'グラデ色1',
    PianoRollColor(255, 0, 0, 255));
  InitializeColorItem(Items.GradientColor2Item, 'グラデ色2',
    PianoRollColor(0, 0, 255, 255));

  Items.DisplayCategoryList[0].Name := 'ピアノ';
  Items.DisplayCategoryList[0].Value := Ord(pdcPiano);
  Items.DisplayCategoryList[1].Name := nil;
  Items.DisplayCategoryList[1].Value := 0;
  Items.DisplayCategoryItem.ItemType := 'select';
  Items.DisplayCategoryItem.Name := '表示分類';
  Items.DisplayCategoryItem.Value := Ord(pdcPiano);
  Items.DisplayCategoryItem.List := @Items.DisplayCategoryList[0];

  Items.RenderDimensionList[0].Name := '2D';
  Items.RenderDimensionList[0].Value := Ord(prd2D);
  Items.RenderDimensionList[1].Name := '3D';
  Items.RenderDimensionList[1].Value := Ord(prd3D);
  Items.RenderDimensionList[2].Name := nil;
  Items.RenderDimensionList[2].Value := 0;
  Items.RenderDimensionItem.ItemType := 'select';
  Items.RenderDimensionItem.Name := '描画方式';
  Items.RenderDimensionItem.Value := Ord(prd2D);
  Items.RenderDimensionItem.List := @Items.RenderDimensionList[0];

  Items.StyleTypeList[0].Name := 'Type1';
  Items.StyleTypeList[0].Value := Ord(pstType1);
  Items.StyleTypeList[1].Name := 'Type2';
  Items.StyleTypeList[1].Value := Ord(pstType2);
  Items.StyleTypeList[2].Name := 'Type3';
  Items.StyleTypeList[2].Value := Ord(pstType3);
  Items.StyleTypeList[3].Name := nil;
  Items.StyleTypeList[3].Value := 0;
  Items.StyleTypeItem.ItemType := 'select';
  Items.StyleTypeItem.Name := '表示タイプ';
  Items.StyleTypeItem.Value := Ord(pstType1);
  Items.StyleTypeItem.List := @Items.StyleTypeList[0];

  Items.StrikeEffectTypeList[0].Name := 'Type1';
  Items.StrikeEffectTypeList[0].Value := Ord(psetType1);
  Items.StrikeEffectTypeList[1].Name := nil;
  Items.StrikeEffectTypeList[1].Value := 0;
  Items.StrikeEffectTypeItem.ItemType := 'select';
  Items.StrikeEffectTypeItem.Name := '発音エフェクト';
  Items.StrikeEffectTypeItem.Value := Ord(psetType1);
  Items.StrikeEffectTypeItem.List := @Items.StrikeEffectTypeList[0];

  Items.OrientationList[0].Name := '縦';
  Items.OrientationList[0].Value := Ord(poVertical);
  Items.OrientationList[1].Name := '横';
  Items.OrientationList[1].Value := Ord(poHorizontal);
  Items.OrientationList[2].Name := nil;
  Items.OrientationList[2].Value := 0;
  Items.OrientationItem.ItemType := 'select';
  Items.OrientationItem.Name := '方向';
  Items.OrientationItem.Value := Ord(poVertical);
  Items.OrientationItem.List := @Items.OrientationList[0];

  Items.KeyboardTypeList[0].Name := '標準ピアノ';
  Items.KeyboardTypeList[0].Value := Ord(pktPiano);
  Items.KeyboardTypeList[1].Name := 'ハープ（7音）';
  Items.KeyboardTypeList[1].Value := Ord(pktHarp7);
  Items.KeyboardTypeList[2].Name := nil;
  Items.KeyboardTypeList[2].Value := 0;
  Items.KeyboardTypeItem.ItemType := 'select';
  Items.KeyboardTypeItem.Name := '鍵盤タイプ';
  Items.KeyboardTypeItem.Value := Ord(pktPiano);
  Items.KeyboardTypeItem.List := @Items.KeyboardTypeList[0];

  Items.SizePresetList[0].Name := '中';
  Items.SizePresetList[0].Value := SIZE_PRESET_MEDIUM;
  Items.SizePresetList[1].Name := '大';
  Items.SizePresetList[1].Value := SIZE_PRESET_LARGE;
  Items.SizePresetList[2].Name := nil;
  Items.SizePresetList[2].Value := 0;
  Items.SizePresetItem.ItemType := 'select';
  Items.SizePresetItem.Name := 'サイズ';
  Items.SizePresetItem.Value := SIZE_PRESET_MEDIUM;
  Items.SizePresetItem.List := @Items.SizePresetList[0];
  Items.SizePresetButton.ItemType := 'button';
  Items.SizePresetButton.Name := 'サイズ適用';
  Items.SizePresetButton.Callback := ApplySizePresetButton;

  // AviUtl2はnil終端された項目ポインター配列を参照する。
  // 通常利用する基本設定を先頭へまとめ、以降に詳細設定を並べる。
  Items.PluginItems[0] := @Items.MusicFileItem;
  Items.PluginItems[1] := @Items.DisplayCategoryItem;
  Items.PluginItems[2] := @Items.RenderDimensionItem;
  Items.PluginItems[3] := @Items.StyleTypeItem;
  Items.PluginItems[4] := @Items.OrientationItem;
  Items.PluginItems[5] := @Items.KeyboardTypeItem;
  Items.PluginItems[6] := @Items.SizePresetItem;
  Items.PluginItems[7] := @Items.SizePresetButton;
  Items.PluginItems[8] := @Items.DisplayTimeItem;
  Items.PluginItems[9] := @Items.DisplayTime3DItem;
  Items.PluginItems[10] := @Items.StrikePositionItem;
  Items.PluginItems[11] := @Items.TimeShiftItem;
  Items.PluginItems[12] := @Items.VisibleNoteCountItem;
  Items.PluginItems[13] := @Items.CenterNoteItem;
  Items.PluginItems[14] := @Items.PitchFollowItem;
  Items.PluginItems[15] := @Items.KeyLengthItem;
  Items.PluginItems[16] := @Items.KeyThicknessItem;
  // 鍵盤との位置関係を調整する項目は、鍵盤寸法の直後へまとめる。
  Items.PluginItems[17] := @Items.RadiusItem;
  Items.PluginItems[18] := @Items.NotePositionOffsetItem;
  Items.PluginItems[19] := @Items.NoteThicknessItem;
  Items.PluginItems[20] := @Items.WhiteKey3DThicknessItem;
  Items.PluginItems[21] := @Items.BlackKey3DThicknessItem;
  Items.PluginItems[22] := @Items.Note3DThicknessItem;
  Items.PluginItems[23] := @Items.ShowLanesItem;
  Items.PluginItems[24] := @Items.ShowBeatLinesItem;
  Items.PluginItems[25] := @Items.BeatsPerMeasureItem;
  Items.PluginItems[26] := @Items.WhiteKeyColorItem;
  Items.PluginItems[27] := @Items.BlackKeyColorItem;
  Items.PluginItems[28] := @Items.WhiteLaneColorItem;
  Items.PluginItems[29] := @Items.BlackLaneColorItem;
  Items.PluginItems[30] := @Items.BeatLineColorItem;
  Items.PluginItems[31] := @Items.MeasureLineColorItem;
  Items.PluginItems[32] := @Items.StrikeLineColorItem;
  Items.PluginItems[33] := @Items.TrackColorModeItem;
  Items.PluginItems[34] := @Items.SingleTrackColorItem;
  Items.PluginItems[35] := @Items.NoteDepthItem;
  Items.PluginItems[36] := @Items.GradientColor1Item;
  Items.PluginItems[37] := @Items.GradientColor2Item;
  Items.PluginItems[38] := @Items.StrikeEffectTypeItem;
  // 入力素材を必要としないため、寸法と再生範囲は本体で保持する。
  InitializeTrackItem(Items.CanvasWidthItem, '描画幅 (0=シーン)', 0, 0, 8192, 1);
  InitializeTrackItem(Items.CanvasHeightItem, '描画高さ (0=シーン)', 0, 0, 8192, 1);
  InitializeTrackItem(Items.StartPositionItem, '開始位置 (秒)', 0, -10, 1800, 1);
  // 曲開始前の余白は10秒までとし、ドラッグの感度は100秒相当に保つ。
  // stepだけでは広い範囲に比例した大きな移動を防げないためtrack2を使う。
  Items.StartPositionItem.ItemType := 'track2';
  Items.StartPositionItem.ZeroDisplay := nil;
  Items.StartPositionItem.SliderRatio := 18.1;
  InitializeTrackItem(Items.PlaybackRateItem, '再生速度 (%)', 100, 0, 800, 0.01);
  Items.PluginItems[39] := @Items.CanvasWidthItem;
  Items.PluginItems[40] := @Items.CanvasHeightItem;
  Items.PluginItems[41] := @Items.StartPositionItem;
  Items.PluginItems[42] := @Items.PlaybackRateItem;
  Items.PluginItems[43] := nil;
  Initialized := True;
end;
end.

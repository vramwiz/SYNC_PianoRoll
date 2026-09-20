unit SYNC_PianoRoll_MediaSettings;

// ホストの設定値を1フレーム分の値型へコピーし、入力元やGUIに依存しない描画設定へ変換する。
interface
uses SYNC_PianoRoll_DisplayTypes;
type
  TPianoRollMediaSettings = record
    MusicFileName: string;
    Width, Height: Integer;
    StartSeconds, PlaybackRatePercent: Double;
    Category, Dimension, Style, Orientation: Integer;
    Display: TPianoRollDisplaySettings;
  end;
procedure ReadPianoRollMediaSettings(out Settings: TPianoRollMediaSettings);
implementation
uses System.Math, System.SysUtils, AviUtl2FilterTypes, SYNC_PianoRoll_MediaItems,
  SYNC_PianoRoll_Colors, SYNC_PianoRoll_PianoKeys;
function GetFilterColor(const Item: TFILTER_ITEM_COLOR;
  Alpha: Byte): TPianoRollColor;
begin
  Result := PianoRollColor(Item.R, Item.G, Item.B, Alpha);
end;

procedure BuildDisplaySettings(out Settings: TPianoRollDisplaySettings);
begin
  SetDefaultPianoRollDisplaySettings(Settings);
  Settings.DisplayTime := EnsureRange(Items.DisplayTimeItem.Value, 0.1, 60.0);
  Settings.DisplayTime3D := EnsureRange(
    Items.DisplayTime3DItem.Value, 0.1, 600.0);
  Settings.StrikePosition := EnsureRange(
    Items.StrikePositionItem.Value / 100.0, 0.0, 1.0);
  Settings.TimeShift := EnsureRange(Items.TimeShiftItem.Value, -60.0, 60.0);
  Settings.VisibleNoteCount := EnsureRange(
    Round(Items.VisibleNoteCountItem.Value), 1, 128);
  Settings.CenterNote := EnsureRange(Round(Items.CenterNoteItem.Value), 0, 127);
  case Items.PitchFollowItem.Value of
    Ord(ppfmAlways):
      Settings.PitchFollowMode := ppfmAlways;
    Ord(ppfmOnOverflow):
      Settings.PitchFollowMode := ppfmOnOverflow;
  else
    // 未知値は基準音域を変えない既定動作へ戻す。
    Settings.PitchFollowMode := ppfmNone;
  end;
  if Items.KeyboardTypeItem.Value = Ord(pktHarp7) then
    Settings.KeyboardType := pktHarp7
  else
    // 未知値は半音を欠落させない標準ピアノへ戻す。
    Settings.KeyboardType := pktPiano;
  Settings.KeyLength := EnsureRange(Items.KeyLengthItem.Value, 0.0, 1000.0);
  Settings.KeyThickness := EnsureRange(
    Items.KeyThicknessItem.Value, 1.0, 200.0);
  Settings.NoteThickness := EnsureRange(
    Items.NoteThicknessItem.Value / 100.0, 0.05, 1.0);
  Settings.WhiteKey3DThickness := EnsureRange(
    Items.WhiteKey3DThicknessItem.Value, 0.0, 500.0);
  Settings.BlackKey3DThickness := EnsureRange(
    Items.BlackKey3DThicknessItem.Value, 0.0, 500.0);
  Settings.Note3DThickness := EnsureRange(
    Items.Note3DThicknessItem.Value, 0.0, 500.0);
  Settings.NotePositionOffset := EnsureRange(
    Items.NotePositionOffsetItem.Value, -500.0, 500.0);
  Settings.Radius := EnsureRange(Items.RadiusItem.Value, 0.0, 5000.0);
  case Items.StrikeEffectTypeItem.Value of
    Ord(psetType1):
      Settings.StrikeEffectType := psetType1;
  else
    // 未知値は既存プロジェクトと同じ初期エフェクトへ戻す。
    Settings.StrikeEffectType := psetType1;
  end;
  Settings.NoteDepthEnabled := Items.NoteDepthItem.Value <> 0;
  Settings.ShowLanes := Items.ShowLanesItem.Value <> 0;
  Settings.ShowBeatLines := Items.ShowBeatLinesItem.Value <> 0;
  Settings.BeatsPerMeasure := EnsureRange(
    Round(Items.BeatsPerMeasureItem.Value), 1, 32);
  if InRange(Items.TrackColorModeItem.Value,
    Ord(Low(TPianoRollTrackColorMode)),
    Ord(High(TPianoRollTrackColorMode))) then
    Settings.TrackColorMode :=
      TPianoRollTrackColorMode(Items.TrackColorModeItem.Value)
  else
    Settings.TrackColorMode := ptcmSingleColor;
  Settings.SingleTrackColor := GetFilterColor(Items.SingleTrackColorItem,
    Settings.SingleTrackColor.A);
  Settings.GradientColor1 := GetFilterColor(Items.GradientColor1Item,
    Settings.GradientColor1.A);
  Settings.GradientColor2 := GetFilterColor(Items.GradientColor2Item,
    Settings.GradientColor2.A);
  Settings.Palette.WhiteKey := GetFilterColor(Items.WhiteKeyColorItem,
    Settings.Palette.WhiteKey.A);
  Settings.Palette.BlackKey := GetFilterColor(Items.BlackKeyColorItem,
    Settings.Palette.BlackKey.A);
  Settings.Palette.WhiteLane := GetFilterColor(Items.WhiteLaneColorItem,
    Settings.Palette.WhiteLane.A);
  Settings.Palette.BlackLane := GetFilterColor(Items.BlackLaneColorItem,
    Settings.Palette.BlackLane.A);
  Settings.Palette.BeatLine := GetFilterColor(Items.BeatLineColorItem,
    Settings.Palette.BeatLine.A);
  Settings.Palette.MeasureLine := GetFilterColor(Items.MeasureLineColorItem,
    Settings.Palette.MeasureLine.A);
  Settings.Palette.StrikeLine := GetFilterColor(Items.StrikeLineColorItem,
    Settings.Palette.StrikeLine.A);
end;


procedure ReadPianoRollMediaSettings(out Settings: TPianoRollMediaSettings);
begin
  Settings.MusicFileName := Trim(string(Items.MusicFileItem.Value));
  Settings.Width := EnsureRange(Round(Items.CanvasWidthItem.Value), 0, 8192);
  Settings.Height := EnsureRange(Round(Items.CanvasHeightItem.Value), 0, 8192);
  Settings.StartSeconds := EnsureRange(Items.StartPositionItem.Value, -10.0, 1800.0);
  Settings.PlaybackRatePercent := EnsureRange(Items.PlaybackRateItem.Value, 0.0, 800.0);
  Settings.Category := Items.DisplayCategoryItem.Value;
  Settings.Dimension := Items.RenderDimensionItem.Value;
  Settings.Style := Items.StyleTypeItem.Value;
  Settings.Orientation := Items.OrientationItem.Value;
  BuildDisplaySettings(Settings.Display);
end;
end.

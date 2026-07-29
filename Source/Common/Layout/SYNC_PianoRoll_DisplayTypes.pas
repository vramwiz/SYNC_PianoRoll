unit SYNC_PianoRoll_DisplayTypes;

// 画面のX/Yに依存しない表示設定と、表示タイプが実装する共通契約を定義する。

interface

uses
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_PianoKeys,
  SYNC_PianoRoll_Colors,
  SYNC_PianoRoll_RGBA;

type
  // Filterの共通入口から選択する表示実装。各実装は専用ユニットに置く。
  TPianoRollDisplayType = (
    pdtVertical,
    pdtHorizontal
  );

  // 基準音域から実効音域を動かす追従方式。
  TPianoRollPitchFollowMode = (
    ppfmNone,
    ppfmAlways,
    ppfmOnOverflow
  );

  TPianoRollDisplaySettings = record
    DisplayTime: Double;      // 発音位置から時間方向の表示端までに含める秒数。
    StrikePosition: Double;   // 時間方向の表示範囲に対する発音位置。0.0～1.0。
    TimeShift: Double;        // 音楽データとタイムラインの同期時刻差。
    VisibleNoteCount: Integer; // 基準音域へ含める連続MIDIノート数。
    CenterNote: Integer;       // 基準音域の中央に置くMIDIノート番号。
    PitchFollowMode: TPianoRollPitchFollowMode; // 実効音域の追従方式。
    KeyboardType: TPianoRollKeyboardType; // 鍵盤と表示対象音の構造。
    KeyLength: Double;        // 鍵盤が伸びる方向の長さ。
    KeyThickness: Double;     // 1鍵の音階方向の太さ。
    NoteThickness: Double;    // 音階方向レーンに対するノートの占有率。
    NoteDepthEnabled: Boolean; // 縁、面取り、つやによる疑似立体表示。
    ShowLanes: Boolean;       // 白鍵・黒鍵に対応するレーン背景を表示する。
    ShowBeatLines: Boolean;   // 拍線と小節線を表示する。
    BeatsPerMeasure: Integer; // 1小節として強調する拍数。
    TrackColorMode: TPianoRollTrackColorMode; // ノートへ適用する配色規則。
    SingleTrackColor: TPianoRollColor;        // 単色配色で使うノート色。
    GradientColor1: TPianoRollColor;          // 音階グラデーションの高音側。
    GradientColor2: TPianoRollColor;          // 音階グラデーションの低音側。
    Palette: TPianoRollPalette;
  end;

  IPianoRollDisplay = interface
    ['{87E69C7A-A213-49D2-936B-F9C15E4D6089}']
    procedure Draw(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      const Settings: TPianoRollDisplaySettings);
  end;

procedure SetDefaultPianoRollDisplaySettings(
  out Settings: TPianoRollDisplaySettings);
function ScalePianoRollThickness(BaseThickness: Integer;
  KeyThickness: Double): Integer;

implementation

uses
  System.Math;

function ScalePianoRollThickness(BaseThickness: Integer;
  KeyThickness: Double): Integer;
begin
  // 旧基準の20pxを1倍とし、中40pxと大60pxで線幅も同率に拡大する。
  Result := Max(1, Round(Max(1, BaseThickness) *
    Max(1.0, KeyThickness) / 20.0));
end;

procedure SetDefaultPianoRollDisplaySettings(
  out Settings: TPianoRollDisplaySettings);
begin
  Settings.DisplayTime := 4.0;
  Settings.StrikePosition := 0.80;
  Settings.TimeShift := 0.0;
  // 初期表示はMIDI全域の半分とし、中央ノートの変更を確認しやすくする。
  Settings.VisibleNoteCount := 64;
  Settings.CenterNote := 64;
  Settings.PitchFollowMode := ppfmNone;
  Settings.KeyboardType := pktPiano;
  // 現在の中プリセットを描画設定の初期寸法として使う。
  Settings.KeyLength := 120.0;
  Settings.KeyThickness := 40.0;
  Settings.NoteThickness := 0.80;
  Settings.NoteDepthEnabled := True;
  Settings.ShowLanes := True;
  Settings.ShowBeatLines := True;
  Settings.BeatsPerMeasure := 4;
  SetDefaultPianoRollPalette(Settings.Palette);
  Settings.TrackColorMode := ptcmSingleColor;
  Settings.SingleTrackColor := Settings.Palette.TrackColors[0];
  Settings.GradientColor1 := PianoRollColor(255, 0, 0, 255);
  Settings.GradientColor2 := PianoRollColor(0, 0, 255, 255);
end;

end.

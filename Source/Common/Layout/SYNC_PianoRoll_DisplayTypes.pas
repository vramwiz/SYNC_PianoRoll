unit SYNC_PianoRoll_DisplayTypes;

// 画面のX/Yに依存しない表示設定と、表示タイプが実装する共通契約を定義する。

interface

uses
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_RGBA;

type
  TPianoRollDisplaySettings = record
    DisplayTime: Double;      // 発音位置から時間方向の表示端までに含める秒数。
    StrikePosition: Double;   // 時間方向の表示範囲に対する発音位置。0.0～1.0。
    TimeShift: Double;        // 音楽データとタイムラインの同期時刻差。
    AutoKeyRange: Boolean;    // 音楽データから表示音域を自動決定する。
    LowestKey: Integer;       // 手動音域の最低MIDIノート番号。
    HighestKey: Integer;      // 手動音域の最高MIDIノート番号。
    KeyLength: Double;        // 鍵盤が伸びる方向の長さ。
    KeyThickness: Double;     // 1鍵の音階方向の太さ。
    NoteThickness: Double;    // 音階方向レーンに対するノートの占有率。
  end;

  IPianoRollDisplay = interface
    ['{87E69C7A-A213-49D2-936B-F9C15E4D6089}']
    procedure Draw(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      const Settings: TPianoRollDisplaySettings);
  end;

procedure SetDefaultPianoRollDisplaySettings(
  out Settings: TPianoRollDisplaySettings);

implementation

procedure SetDefaultPianoRollDisplaySettings(
  out Settings: TPianoRollDisplaySettings);
begin
  Settings.DisplayTime := 4.0;
  Settings.StrikePosition := 0.80;
  Settings.TimeShift := 0.0;
  Settings.AutoKeyRange := False;
  Settings.LowestKey := 0;
  Settings.HighestKey := 127;
  Settings.KeyLength := 60.0;
  Settings.KeyThickness := 20.0;
  Settings.NoteThickness := 0.80;
end;

end.

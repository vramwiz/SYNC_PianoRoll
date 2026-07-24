# SYNC_PianoRoll 作業ノート

## 目的

MIDI等の音楽データを読み、AviUtl2上で鍵盤とノートを音楽へ同期して描画する。
`SYNC_Motion` と同様に、入力プラグインと映像フィルタープラグインの2つで構成する。

## 現在の最小構成

- `SYNC_PianoRoll_Input.dpr/.dproj`: 透明映像を返す入力プラグイン。成果物は `.aui2`。
- `SYNC_PianoRoll_Filter.dpr/.dproj`: 現在は映像を無加工で通すフィルタープラグイン。成果物は `.auf2`。
- `Source\SYNC_PianoRoll_InputPlugin.pas`: 仮想素材の寸法、長さ、フレームレートを解釈する。
- `Source\SYNC_PianoRoll_FilterPlugin.pas`: フィルター登録と映像処理の入口。
- `Source\Lib\AviUtl2InputTypes.pas`: 入力プラグインSDKの最小Delphi ABI定義。
- `Source\Lib\AviUtl2FilterTypes.pas`: フィルタープラグインSDKの最小Delphi ABI定義。

AviUtl2上の識別名は次の値で固定する。

```text
SYNC_ピアノロール_Input
SYNC_ピアノロール_Filter
```

入力用の仮想素材拡張子は `.syncpianoroll` とし、次のファイル名形式を解釈する。

```text
Width_Height_MaxSec_Fps_Scale.syncpianoroll
```

値を省略または解釈できない場合は、幅1、高さ1、3600秒、30fps、scale 1を使う。

## ビルド

Delphi 37.0、Win64のみを対象にし、DebugとReleaseを保つ。
出力先は `C:\ProgramData\aviutl2\Plugin\SYNC_PianoRoll` とする。
DebugではDLLとRSMを残し、Releaseではプラグイン拡張子へコピー後にDLLとRSMを削除する。

Input Debug Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_PianoRoll\SYNC_PianoRoll_Input.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Filter Debug Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_PianoRoll\SYNC_PianoRoll_Filter.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Input Release Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_PianoRoll\SYNC_PianoRoll_Input.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

Filter Release Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_PianoRoll\SYNC_PianoRoll_Filter.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

## 次の実装候補

1. InputからFilterへ絶対フレーム位置を共有する。
2. MIDI等の音楽データを読み、解析結果を読み取り専用キャッシュとして共有する。
3. 鍵盤とノートを描画する。
4. 縦向き・横向き、表示時間、鍵盤範囲、色等の設定を追加する。

## 作業ログ

- 2026-07-24: `SYNC_Motion`を参考に最小プロジェクトを作成した。Inputは透明映像を返し、Filterは映像を無加工で通す。
- 2026-07-24: Input／FilterのDebug・Release Win64をビルドし、4構成すべて警告0、エラー0を確認した。
- 2026-07-24: Release成果物を専用フォルダーへ配置し、Inputの`GetInputPluginTable`とFilterの
  `InitializePlugin`、`UninitializePlugin`、`GetFilterPluginTable`をロードできることを確認した。

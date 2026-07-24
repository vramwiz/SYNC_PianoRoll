# SYNC_PianoRoll 作業ノート

## 目的

MIDI等の音楽データを読み、AviUtl2上で鍵盤とノートを音楽へ同期して描画する。
`SYNC_Motion` と同様に、入力プラグインと映像フィルタープラグインの2つで構成する。

## 現在の最小構成

- `SYNC_PianoRoll_Input.dpr/.dproj`: 透明映像を返す入力プラグイン。成果物は `.aui2`。
- `SYNC_PianoRoll_Filter.dpr/.dproj`: 現在は映像を無加工で通すフィルタープラグイン。成果物は `.auf2`。
- `Source\SYNC_PianoRoll_InputPlugin.pas`: 仮想素材の寸法、長さ、フレームレートを解釈する。
- `Source\SYNC_PianoRoll_FilterPlugin.pas`: フィルター登録、共有フレーム受信、映像処理の入口。
- `Source\SYNC_PianoRoll_ContextManager.pas`: Object IDとEffect IDごとに共有フレームとローカルフレームの対応を保持する。
- `Source\Lib\AviUtl2InputTypes.pas`: 入力プラグインSDKの最小Delphi ABI定義。
- `Source\Lib\AviUtl2FilterTypes.pas`: フィルタープラグインSDKの最小Delphi ABI定義。
- `Source\Lib\SharedMemoryBase.pas`: 名前付き共有メモリの最小基礎処理。
- `Source\Lib\SYNC_PianoRoll_FrameShared.pas`: InputとFilter間で絶対フレーム、rate、scale、秒位置を共有する。
- `Tests\SYNC_PianoRoll_FrameContextTests.dpr`: 共有メモリとオブジェクト別フレーム補間の回帰テスト。

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

## フレーム共有とコンテキスト管理

Inputの映像読込コールバックで、読み出された絶対フレーム、rate、scale、秒位置、更新時刻を
名前付き共有メモリ`Local\SYNC_PianoRoll_Frame_V1`へ公開する。画像サイズは共有対象に含めない。

共有レコードは更新番号を持つ。Inputは更新番号を偶数から奇数へ変更できた場合だけ値を書き込み、
書き込み完了時に次の偶数へ進める。Filterは読み込み前後の更新番号が同じ偶数である場合だけ値を採用し、
書き込み途中のフレーム、rate、scale、秒位置が混在しないようにする。

Inputの映像キャッシュにより同じ素材の読込コールバックが再発火しない場合に備え、Filterは最初に受信した
共有絶対フレームと、その時点の`Object_.Frame`を基準として記憶する。共有更新番号が変わらない間は、
現在の`Object_.Frame`との差を共有絶対フレームへ加算して有効フレームと秒位置を補間する。
新しい共有更新番号を受信した場合は、その値で基準を更新する。

基準は`Object_.ID + Object_.EffectID`ごとの独立コンテキストとして保持する。同じ共有値を参照する
複数オブジェクト、および同一オブジェクト上の複数Filterで基準を混在させない。
コンテキストの検索、作成、基準更新は排他して行い、AviUtl2からの並列呼び出しに備える。

## 旧Syncroh2の参照実装

ピアノロール機能の仕様と実装を調査する際は、次の旧`Syncroh2`資産を参照する。

```text
D:\DelphiProg\test\Syncroh2\Syncroh2_Filter_PianoRoll.dpr
D:\DelphiProg\test\Syncroh2\Plugin_Filter\PianoRoll
D:\DelphiProg\test\Syncroh2\Plugin_Extension\Music\PianoRoll
```

- `Syncroh2_Filter_PianoRoll.dpr`: 旧ピアノロールフィルターのプロジェクト構成と使用ユニットを確認する。
- `Plugin_Filter\PianoRoll`: フィルター登録、設定項目、ピアノロール描画処理を確認する。
- `Plugin_Extension\Music\PianoRoll`: 音楽データからピアノロール表示へ変換する処理を確認する。
- 旧構成をそのままコピーせず、現在のInput／Filter構成に必要な処理と依存ユニットだけを選別して取り込む。
- 現在のAviUtl2 SDK ABI、安全方針、並列呼び出し、キャッシュ設計を優先し、旧実装との差異を確認して移植する。

## 旧実装からの重要な変更

旧`Syncroh2`では、事前に生成または保存されたINIファイルを介してピアノロール用データを参照していた。
`SYNC_PianoRoll`ではINIファイルを入力元とせず、MIDI等の元音楽ファイルをFilterから直接参照して解析する。

- 利用者は中間INIファイルを用意せず、Filterの設定項目で元音楽ファイルを指定する。
- 対応形式はSongReaderの採用範囲を決めた後に確定し、Filterのファイル選択候補へ列挙する。
- 解析結果は元ファイルの正規化した絶対パス、更新日時、ファイルサイズ等を基準にキャッシュする。
- 同じ音楽ファイルを複数オブジェクトが参照する場合は、解析結果を読み取り専用で共有する。
- 元ファイルの不存在、未知形式、破損、解析失敗時は例外をAviUtl2へ漏らさず、安全に無描画または無加工で通す。
- 旧INIの構造や保存方式との互換性は前提にせず、必要な表示設定だけを新しい構成で定義する。

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
- 2026-07-24: Git環境を`SYNC_Motion`と比較した。`main`と`origin/main`、リモートURL、利用者設定、
  追跡対象、除外規則は共通方針に一致している。管理対象テキストの作業ツリー改行をCRLFへ統一した。
- 2026-07-24: 旧`Syncroh2`のピアノロール用プロジェクト、フィルター実装、音楽拡張実装の参照先を記録した。
- 2026-07-24: 旧INI参照方式を移植せず、元音楽ファイルをFilterから直接参照して解析する方針を記録した。
- 2026-07-24: InputからFilterへ絶対フレームを渡す名前付き共有メモリと、Object ID＋Effect ID別の
  コンテキスト管理を追加した。共有更新が停止した場合はFilterローカルフレーム差分で補間する。
- 2026-07-24: 共有メモリ、2オブジェクト、同一Object ID上の別Effect、更新停止時の補間、
  新しい共有値による再基準化を回帰テストし、PASSを確認した。Debug／Releaseの4構成は警告0、エラー0。

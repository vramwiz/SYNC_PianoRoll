# SYNC_PianoRoll 作業ノート

## 目的

MIDI等の音楽データを読み、AviUtl2上で鍵盤とノートを音楽へ同期して描画する。
`SYNC_Motion` と同様に、入力プラグインと映像フィルタープラグインの2つで構成する。

## 現在の最小構成

- `SYNC_PianoRoll_Input.dpr/.dproj`: 透明映像を返す入力プラグイン。成果物は `.aui2`。
- `SYNC_PianoRoll_Filter.dpr/.dproj`: 音楽ファイルを解析し、選択した表示実装へ描画を委譲するフィルタープラグイン。成果物は `.auf2`。
- `Source\Plugin\Input\SYNC_PianoRoll_InputPlugin.pas`: 仮想素材の寸法、長さ、フレームレートを解釈する。
- `Source\Plugin\Filter\SYNC_PianoRoll_FilterPlugin.pas`: フィルター登録、設定取得、共有フレーム受信、表示実装の選択を担当する。
- `Source\Common\Timeline\SYNC_PianoRoll_FrameShared.pas`: InputとFilter間で絶対フレーム、rate、scale、秒位置を共有する。
- `Source\Common\Timeline\SYNC_PianoRoll_ContextManager.pas`: Object IDとEffect IDごとに共有フレームとローカルフレームの対応を保持する。
- `Source\Common\Data\SYNC_PianoRoll_MusicData.pas`: 元音楽ファイルの解析結果を描画用の読み取り専用スナップショットとして共有する。
- `Source\Common\Layout\SYNC_PianoRoll_DisplayTypes.pas`: 縦横に依存しない表示設定と表示実装の共通契約を定義する。
- `Source\Common\Render\SYNC_PianoRoll_RGBA.pas`: 表示タイプに依存しないRGBAキャンバスと矩形描画を提供する。
- `Source\Common\Render\SYNC_PianoRoll_Renderer.pas`: オブジェクト別描画バッファを管理し、選択された表示実装を呼び出す。
- `Source\Display\Vertical\SYNC_PianoRoll_VerticalDisplay.pas`: 時間方向を下向き、音階方向を左から右へ割り当てる縦表示を担当する。
- `Source\Lib\AviUtl2InputTypes.pas`: 入力プラグインSDKの最小Delphi ABI定義。
- `Source\Lib\AviUtl2FilterTypes.pas`: フィルタープラグインSDKの最小Delphi ABI定義。
- `Source\Lib\SharedMemoryBase.pas`: 名前付き共有メモリの最小基礎処理。
- `Source\Lib\SongReader`: `SYNC_Motion`から導入したMIDI、UST、VSQX、MusicXML、MuseScore解析処理。
- `Tests\SYNC_PianoRoll_FrameContextTests.dpr`: 共有メモリとオブジェクト別フレーム補間の回帰テスト。
- `Tests\SYNC_PianoRoll_MusicDataTests.dpr`: 最小MIDIの直接解析とキャッシュ更新の回帰テスト。
- `Tests\SYNC_PianoRoll_PianoKeyTests.dpr`: 白鍵・黒鍵判定と白鍵単位の音階方向位置を検証する。
- `Tests\SYNC_PianoRoll_PluginLoadTests.dpr`: Filter登録表と音楽ファイル項目のロードテスト。
- `Tests\SYNC_PianoRoll_RenderTests.dpr`: RGBA出力、ノート矩形、出力サイズ変更を検証する描画テスト。

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

## 作り直しと再利用の方針

旧`Syncroh2`のピアノロール全体をそのまま移植しない。新しい構造で作り直し、単独で責務を説明でき、
現在の設計へ無理なく適合できる処理だけを選別して再利用する。旧実装は部品の参照元、動作見本、
仕様確認用として残し、新版のクラス構造やデータ経路の基礎にはしない。

再利用候補は次のとおり。

- SongReaderによる元音楽ファイルの解析。
- MIDIキー、音階、白鍵、黒鍵等の判定。
- トラック別、音階別、階名別の配色計算。
- ノート、鍵盤、拍線等の座標計算式。
- 実際の利用で必要性が確認された初期値、範囲、描画順序。

次の処理は新しい設計で作る。

- Input／Filter間の共有メモリと時刻同期。
- 読み取り専用音楽データ、キャッシュ、並列呼び出し対策。
- 表示タイプを選択し、専用処理へ委譲する仕組み。
- レイアウト計算とRGBA描画の分離。
- AviUtl2の設定項目と安全なコールバック境界。
- 表示設定の保持方法と、将来必要になる永続データの形式。

旧INIを中心としたデータ経路、RTTI／INI保存クラス、VCLフォーム、`TBitmap`依存の描画、
旧共有メモリ、旧コンテキスト管理、複数の責務が混在した巨大ユニットは移植しない。

## ソースフォルダーの分離方針

旧実装では共通処理と表示タイプ固有処理の置き場所が分かりにくくなったため、今後は責務と再利用範囲を
フォルダーで明示する。共通処理から縦表示や横表示の実装を参照せず、各表示タイプから共通処理を利用する
一方向の依存関係とする。表示タイプ同士は互いを参照しない。

次の構成を基本とする。Input／Filter入口、データ、時刻同期、表示契約、RGBA描画、縦表示は
2026-07-24にこの構成へ移動済み。`Color`と`Horizontal`は実装を開始した時点で追加する。

```text
Source
├─ Plugin
│  ├─ Input
│  └─ Filter
├─ Common
│  ├─ Data
│  ├─ Timeline
│  ├─ Layout
│  ├─ Render
│  └─ Color
├─ Display
│  ├─ Vertical
│  └─ Horizontal
└─ Lib
   ├─ SongReader
   └─ AviUtl2 SDK／汎用基礎処理
```

- `Source\Plugin`: AviUtl2への登録、コールバック、設定値の受け渡しだけを担当する。
- `Source\Common\Data`: 読み取り専用音楽データ、ノート、拍、トラック、キャッシュを置く。
- `Source\Common\Timeline`: 共有フレーム、オブジェクト別コンテキスト、時刻変換を置く。
- `Source\Common\Layout`: 表示タイプが実装する共通契約、座標、矩形等の値型を置く。
- `Source\Common\Render`: RGBAバッファ、線、矩形、クリップ等の表示タイプに依存しない描画処理を置く。
- `Source\Common\Color`: トラック、音階、階名等の共通配色処理を置く。
- `Source\Display\Vertical`: 縦表示だけのレイアウト、鍵盤、ノート、拍線、発音表示を置く。
- `Source\Display\Horizontal`: 横表示だけのレイアウト、鍵盤、ノート、拍線、発音表示を置く。
- `Source\Lib`: SongReader、AviUtl2 SDK定義、共有メモリ基礎等の汎用または移入ライブラリを置く。

縦横の切り替えを共通ユニット内の大きな`case`文で処理しない。共通の表示契約を各タイプが別々に実装し、
Filterは選択されたタイプへ処理を委譲する。新しい表示タイプを追加する場合も専用フォルダーを作り、
既存の縦表示、横表示へ処理を追記しない。

テストも共通処理、縦表示、横表示で分離する。共通テストは表示タイプのユニットへ依存させず、
各表示タイプの座標と描画結果はそれぞれの専用テストで検証する。

## パラメータ命名方針

旧パラメータ名との互換性は前提にせず、初期実装時に名称を作り直す。共通項目には縦、横、上、下、
左、右等の特定レイアウトを前提とする語を使わず、縦表示と横表示のどちらでも意味が変わらない名称にする。
公開後は設定取得、書き戻し、既存プロジェクトとの互換性へ影響するため、確定名を安易に変更しない。

共通項目の名称候補は次のとおり。

| 名称候補 | 意味 |
| --- | --- |
| `表示タイプ` | 縦、横、将来追加する表示方式を選択する |
| `表示時間` | 発音位置から時間方向の表示端までに含める秒数 |
| `発音位置` | 時間方向の表示範囲内でノートが発音する位置 |
| `ずらし` | 音楽データとタイムラインの同期時刻差 |
| `最低音` | 表示するMIDIノート番号の下限 |
| `最高音` | 表示するMIDIノート番号の上限 |
| `音域自動` | 曲中のノートから表示音域を自動決定するか |
| `ノート太さ` | 音階方向に対するノート矩形の太さ |
| `鍵盤の長さ` | 鍵盤が伸びる方向の長さ。縦横表示で同じ値を使う |
| `鍵盤の太さ` | 1鍵が音階方向に占める太さ。縦横表示で同じ値を使う |
| `トラック` | 表示対象トラックの選択または絞り込み |

方向を説明する必要がある場合は、画面上の縦横ではなく`時間方向`と`音階方向`を優先する。
縦表示だけ、または横表示だけに存在する設定は共通項目へ混在させず、各表示タイプの専用設定として定義する。
GUIで表示タイプ別の項目を切り替えられない場合も、内部の設定構造とユニットは完全に分離しておく。

## 音楽ファイル解析とキャッシュ

Filterの`音楽ファイル`項目から元音楽ファイルを直接参照する。対応候補はSongReaderが扱う
`.mid`、`.midi`、`.ust`、`.vsq`、`.vsqx`、`.musicxml`、`.mxl`、`.xml`、`.mscx`、`.mscz`。
解析入口には内部保存形式用の`TSongData.LoadFromFile`ではなく、元音楽ファイル用の
`TSongData.LoadFromMusicFile`を使用する。

解析後は`TSongData`の可変オブジェクトをそのまま公開せず、ノート、拍、トラック、曲長を
`IPianoRollMusicData`の読み取り専用スナップショットへコピーする。ノートは開始秒、終了秒、
MIDIノート番号、ベロシティ、トラック番号、歌詞を保持する。拍は秒位置、番号、テンポを保持し、
トラックは番号と名称を保持する。

キャッシュキーには正規化した絶対パスを使用し、更新日時またはファイルサイズが変わった場合だけ
再解析する。同じファイルを指定した複数Filterは同じスナップショットを参照する。
キャッシュ置換後も既存の参照が解放されるまでスナップショットを保持できるよう、インターフェースで
参照カウントする。キャッシュ検索、生成、置換は排他して行う。

ファイル不存在、未知形式、破損、解析失敗、ファイルI/O例外は無効として扱い、画面表示や例外送出を
行わず映像を無加工で通す。無効な既存ファイルも更新日時とサイズが変わるまで再解析しない。

## 最小ピアノロール描画

現在は旧VCL描画系を移植せず、SDKの`SetImageData`へ透明RGBAバッファを直接渡す。
出力サイズはFilter対象の`Object_.Width`と`Object_.Height`を使用するため、仮想素材名で必要な寸法を
指定する。例えば1280×720、600秒、30fpsの描画ベースは次の名前にする。

```text
1280_720_600_30_1.syncpianoroll
```

縦表示では指定音域の低音を左、高音を右へ配置する。
発音位置は時間方向の80%とし、白い水平線で表示する。発音位置から時間方向の表示端までを
`表示時間`（初期値4秒）として座標へ変換し、未来のノートが上から発音位置へ流れる。
終了秒が未確定のノートは0.2秒として扱う。
現在時刻を過ぎて終了したノートは描画しない。ノート色はトラック番号ごとの6色で仮表示する。

鍵盤とノートの音階方向位置は、半音を単純に等分せず、白鍵1個を1.0とする共通音階座標で計算する。
`鍵盤の太さ`（初期値20px）は白鍵1個の音階方向サイズ、`鍵盤の長さ`（初期値60px）は
発音位置から時間方向へ伸びる白鍵の長さとする。黒鍵は白鍵間の中心へ太さ62%、長さ62%で重ねる。
指定音域の中央を画面中央へ置き、画面外の鍵盤とノートはRGBAキャンバスでクリップする。
音域端が黒鍵の場合は隣接する白鍵まで内部表示範囲を広げ、黒鍵だけが浮かないようにする。

描画バッファは`Object_.ID + Object_.EffectID`ごとのレンダーコンテキストへ保持する。
同じ出力サイズでは毎フレーム再利用し、寸法が変わった場合だけ再確保する。同じコンテキストの描画は
個別に排他し、異なるオブジェクトの描画を不要に直列化しない。Filter終了時に全バッファを解放する。

内部設定は`表示時間`、`発音位置`、`ずらし`、`音域自動`、`最低音`、`最高音`、
`鍵盤の長さ`、`鍵盤の太さ`、`ノート太さ`という方向非依存の意味で保持する。
現在の初期値は、GUI設定項目の設計後にFilterの設定へ移す。

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

1. 旧実装から拍位置と小節判定の純粋処理を選別する。
2. 縦表示専用フォルダーへレーン背景と拍線の描画を追加する。
3. 方向非依存の表示設定をFilterのGUI項目へ接続する。
4. 縦表示の完成後、独立した横表示実装と専用テストを追加する。

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
- 2026-07-24: `SYNC_Motion`のSongReader一式を導入し、Filterへ`音楽ファイル`項目と
  読み取り専用スナップショットキャッシュを追加した。旧INIは介さず元音楽ファイルを直接解析する。
- 2026-07-24: 最小MIDIからノート番号60、ベロシティ100、開始0秒、終了0.5秒を取得し、
  同一ファイルでのキャッシュ再利用とファイルサイズ変更後の再解析を確認した。
  Filter登録表のロードテストもPASSし、Debug／Releaseの4構成は警告0、エラー0。
- 2026-07-24: 透明RGBAバッファへ縦方向のノート矩形と発音位置線を描く最小レンダラーを追加した。
  Object ID＋Effect ID別に描画バッファを再利用し、出力寸法が変わる場合だけ再確保する。
- 2026-07-24: 640×360と320×180のRGBA出力、ノート矩形描画、サイズ変更を回帰テストし、
  PASSを確認した。Debug／Releaseの4構成は警告0、エラー0。
- 2026-07-24: 旧ピアノロールをそのまま移植せず、新しい構造で作り直し、解析、判定、配色、
  座標計算等の独立した処理だけを選別して再利用する方針を確定した。
- 2026-07-24: 共通処理、プラグイン入口、縦表示、横表示、外部ライブラリをフォルダーで分離し、
  表示タイプ同士を完全に独立させる目標構成と、縦横に依存しないパラメータ命名方針を記録した。
- 2026-07-24: Input／Filter入口、共有フレームとコンテキスト、音楽データ、表示契約、RGBA描画、
  縦表示を`Source\Plugin`、`Source\Common`、`Source\Display\Vertical`へ実際に分離した。
  共通レンダラーから縦表示の座標計算を除き、`IPianoRollDisplay`を通じて表示実装へ委譲する構成にした。
- 2026-07-24: 新構成で共有フレーム／コンテキスト、音楽解析、縦表示RGBA描画、Filter DLLロードの
  4テストがPASSした。Input／FilterのDebug・Release Win64も4構成すべてビルド成功した。
- 2026-07-24: 旧実装から12音の白鍵／黒鍵規則だけを抽出し、
  `Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas`へ方向非依存の判定と音階位置計算を追加した。
- 2026-07-24: 縦表示へ白鍵、黒鍵、境界線を追加し、ノートも同じ白鍵単位の音階座標へ揃えた。
  `鍵盤の長さ`と`鍵盤の太さ`を縦表示の時間方向と音階方向へ割り当てた。
- 2026-07-24: 白鍵／黒鍵判定、共有フレーム／コンテキスト、音楽解析、RGBA鍵盤・ノート描画、
  Filter DLLロードの5テストがPASSした。Input／FilterのDebug・Release Win64も全4構成で
  ビルド成功し、Releaseの`.auf2`をロードできることを確認した。

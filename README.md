# SYNC_PianoRoll

SYNC_PianoRollは、MIDIなどの音楽ファイルを読み込み、音楽に同期した鍵盤とノートをAviUtl2上へ表示するプラグインです。

## 対応ファイル

現在、次の音楽ファイルに対応しています。

| 種類 | 拡張子 |
| --- | --- |
| MIDI | `.mid`、`.midi` |
| UTAU | `.ust` |
| VOCALOID | `.vsq`、`.vsqx` |
| MusicXML | `.musicxml`、`.mxl`、`.xml` |
| MuseScore | `.mscx`、`.mscz` |

## 導入方法

1. 配布ファイルを展開します。
2. 展開したプラグイン一式を、次のAviUtl2プラグインフォルダへ配置します。

   ```text
   C:\ProgramData\aviutl2\Plugin
   ```

   `Plugin`フォルダの中にサブフォルダを作成して配置しても構いません。例えば、配布ファイルに含まれる`SYNC_PianoRoll`フォルダをそのまま配置すると、次のような構成になります。

   ```text
   C:\ProgramData\aviutl2\Plugin\SYNC_PianoRoll
   ├─ SYNC_PianoRoll_Filter.auf2
   ├─ SYNC_PianoRoll_Input.aui2
   └─ Object
      ├─ 1080x1080_30fps.object
      ├─ 1080x1920_30fps.object
      ├─ 1920x1080_30fps.object
      └─ 1920x1080_60fps.object
   ```

3. AviUtl2を起動します。すでに起動している場合は、プラグインを読み込むために再起動してください。

## 使い方

配置した`SYNC_PianoRoll`フォルダ内の`Object`フォルダを開き、使用する動画の解像度とフレームレートに合う`.object`ファイルをAviUtl2のタイムラインへドラッグ＆ドロップします。

例えば、1920×1080、30fpsの動画では次のファイルを使用します。

```text
Object\1920x1080_30fps.object
```

タイムラインへ追加されたオブジェクトの設定から、表示する音楽ファイルやトラック、ピアノロールの種類を指定します。

## 音楽ファイルの指定

<!-- 詳細を追記予定 -->

## トラックの指定

<!-- 詳細を追記予定 -->

## ピアノロールの種類

<!-- 詳細を追記予定 -->

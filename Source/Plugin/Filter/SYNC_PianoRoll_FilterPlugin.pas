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
  System.SysUtils,
  SYNC_PianoRoll_ContextManager,
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_FrameShared,
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_Renderer,
  SYNC_PianoRoll_VerticalDisplay;

var
  MusicFileItem: TFILTER_ITEM_FILE;
  PianoRollDisplay: IPianoRollDisplay;
  PianoRollDisplaySettings: TPianoRollDisplaySettings;
  PluginItems: array[0..1] of Pointer;

function PianoRollProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
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
            RenderPianoRoll(Video, MusicData, EffectiveState.TimeSeconds,
              PianoRollDisplay, PianoRollDisplaySettings);
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
begin
  if Plugin.Items = nil then
  begin
    MusicFileItem.ItemType := 'file';
    MusicFileItem.Name := '音楽ファイル';
    MusicFileItem.Value := '';
    MusicFileItem.FileFilter :=
      '音楽ファイル (*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz)'#0 +
      '*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz'#0#0;

    // AviUtl2はnil終端された項目ポインター配列を参照する。
    PluginItems[0] := @MusicFileItem;
    PluginItems[1] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializePianoRollFilter;
begin
  SetDefaultPianoRollDisplaySettings(PianoRollDisplaySettings);
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

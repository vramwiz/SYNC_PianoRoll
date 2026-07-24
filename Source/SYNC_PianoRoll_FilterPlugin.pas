unit SYNC_PianoRoll_FilterPlugin;

// ピアノロールフィルターの登録と映像処理の入口を提供する。

interface

uses
  AviUtl2FilterTypes;

function GetPianoRollFilterTable: PFILTER_PLUGIN_TABLE;
procedure InitializePianoRollFilter;
procedure FinalizePianoRollFilter;

implementation

function PianoRollProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  // 最小構成では入力映像を変更しない。
  Result := 1;
end;

var
  PluginItems: array[0..0] of Pointer;
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
    // 項目がない段階でもAviUtl2へnil終端配列を渡す。
    PluginItems[0] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializePianoRollFilter;
begin
end;

procedure FinalizePianoRollFilter;
begin
end;

end.

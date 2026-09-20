unit SYNC_PianoRoll_MediaPlugin;

// 「ピアノロール」メディアオブジェクトのDLL境界と、1フレームの処理を統括する。
interface
uses AviUtl2FilterTypes;
function GetPianoRollMediaTable: PFILTER_PLUGIN_TABLE;
procedure InitializePianoRollMedia;
procedure FinalizePianoRollMedia;
implementation
uses SYNC_PianoRoll_MediaItems, SYNC_PianoRoll_MediaSettings,
  SYNC_PianoRoll_MediaTime, SYNC_PianoRoll_MediaDispatch, SYNC_PianoRoll_MusicData;

function PianoRollProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Settings: TPianoRollMediaSettings;
  Data: IPianoRollMusicData;
  Seconds: Double;
  ObjectInfo: TOBJECT_INFO;
  LocalVideo: TFILTER_PROC_VIDEO;
begin
  // 初期入力なので、未指定・解析失敗時は標準の素材画像を出力しない。
  Result := 0;
  try
    if (Video = nil) or (Video^.Object_ = nil) or (Video^.Scene = nil) then Exit;
    ReadPianoRollMediaSettings(Settings);
    if not TryGetPianoRollMediaTime(Video, Settings.StartSeconds,
      Settings.PlaybackRatePercent, Seconds) then Exit;
    if not TryGetPianoRollMusicData(Settings.MusicFileName, Data) then Exit;
    // 初期入力時のObject.Width/Heightは未確定。ホスト領域を書き換えず寸法だけ補う。
    ObjectInfo := Video^.Object_^;
    ObjectInfo.Width := Settings.Width;
    ObjectInfo.Height := Settings.Height;
    if ObjectInfo.Width = 0 then ObjectInfo.Width := Video^.Scene^.Width;
    if ObjectInfo.Height = 0 then ObjectInfo.Height := Video^.Scene^.Height;
    if (ObjectInfo.Width <= 0) or (ObjectInfo.Height <= 0) or
      (ObjectInfo.Width > 16384) or (ObjectInfo.Height > 16384) then Exit;
    LocalVideo := Video^;
    LocalVideo.Object_ := @ObjectInfo;
    // 2Dだけ標準出力へ渡す。DrawPoly後はfalseを返し二重出力を防ぐ。
    if DrawPianoRollMedia(@LocalVideo, Data, Seconds, Settings) = prrImage then
      Result := 1;
  except
    // Delphi例外をホストへ漏らさず、そのフレームは無描画にする。
    Result := 0;
  end;
end;

var
  Plugin: TFILTER_PLUGIN_TABLE = (
    Flag: FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT;
    Name: 'ピアノロール';
    Label_: 'SYNC';
    Information: '音楽に同期するピアノロール。3D表示にはカメラ制御が必要です。';
    Items: nil;
    Func_Proc_Video: PianoRollProcVideo;
    Func_Proc_Audio: nil
  );

function GetPianoRollMediaTable: PFILTER_PLUGIN_TABLE;
begin
  InitializePianoRollMediaItems;
  Plugin.Items := @Items.PluginItems[0];
  Result := @Plugin;
end;

procedure InitializePianoRollMedia;
begin
  InitializePianoRollMediaItems;
  InitializePianoRollMusicCache;
  InitializePianoRollMediaDisplays;
end;
procedure FinalizePianoRollMedia;
begin
  FinalizePianoRollMediaDisplays;
  FinalizePianoRollMusicCache;
end;
end.

unit SYNC_PianoRoll_Time;

// 単体FilterまたはInput＋Filterの配置方式に応じた音楽同期時刻を取得する。

interface

uses
  AviUtl2FilterTypes;

function TryGetPianoRollTimeSeconds(Video: PFILTER_PROC_VIDEO;
  out TimeSeconds: Double): Boolean;

implementation

uses
  SYNC_PianoRoll_ContextManager,
  SYNC_PianoRoll_FrameShared;

function TryGetPianoRollTimeSeconds(Video: PFILTER_PROC_VIDEO;
  out TimeSeconds: Double): Boolean;
begin
  var EffectiveState: TSyncPianoRollFrameState;
  var SharedState: TSyncPianoRollFrameState;

  Result := False;
  TimeSeconds := 0.0;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  // フィルタオブジェクトには対応するInputがないため、配置先頭からのローカル時刻を使う。
  if (Video^.Object_^.Flag and OBJECT_INFO_FLAG_FILTER_OBJECT) <> 0 then
  begin
    TimeSeconds := Video^.Object_^.Time;
    Exit(True);
  end;

  // メディアオブジェクトではInputが返した開始時間込みのフレームを優先する。
  // 同一フレームの再描画でInputが再取得されない場合は、オブジェクト別基準から補間する。
  if TryReadPianoRollFrame(SharedState) and
    ResolvePianoRollFrameState(Video, SharedState, EffectiveState) then
  begin
    TimeSeconds := EffectiveState.TimeSeconds;
    Exit(True);
  end;

  // 共有値がまだ無い場合も、単体配置時と同じ安全な無補正表示を継続する。
  TimeSeconds := Video^.Object_^.Time;
  Result := True;
end;

end.

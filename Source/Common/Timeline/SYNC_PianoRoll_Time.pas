unit SYNC_PianoRoll_Time;

// Filter対象へ渡されたローカル再生時刻を音楽同期用に取得する。

interface

uses
  AviUtl2FilterTypes;

function TryGetPianoRollTimeSeconds(Video: PFILTER_PROC_VIDEO;
  out TimeSeconds: Double): Boolean;

implementation

function TryGetPianoRollTimeSeconds(Video: PFILTER_PROC_VIDEO;
  out TimeSeconds: Double): Boolean;
begin
  Result := False;
  TimeSeconds := 0.0;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  // 配置方式に依存せず、Filter対象の先頭を音楽データの0秒に合わせる。
  TimeSeconds := Video^.Object_^.Time;
  Result := True;
end;

end.

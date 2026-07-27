unit SYNC_PianoRoll_Time;

// 単体フィルターオブジェクトへ渡されたローカル再生時刻を取得する。

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

  // 配置位置に依存せず、単体フィルターの先頭を音楽データの0秒に合わせる。
  TimeSeconds := Video^.Object_^.Time;
  Result := True;
end;

end.

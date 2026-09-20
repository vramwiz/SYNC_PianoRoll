unit SYNC_PianoRoll_MediaTime;

// 単体メディアのローカルフレームと明示した開始位置・速度から音楽時刻を求める。
interface
uses AviUtl2FilterTypes;
function TryGetPianoRollMediaTime(Video: PFILTER_PROC_VIDEO;
  StartSeconds, PlaybackRatePercent: Double; out Seconds: Double): Boolean;
implementation
uses System.Math;
function TryGetPianoRollMediaTime(Video: PFILTER_PROC_VIDEO;
  StartSeconds, PlaybackRatePercent: Double; out Seconds: Double): Boolean;
begin
  Seconds := 0;
  Result := (Video <> nil) and (Video^.Object_ <> nil) and
    (Video^.Scene <> nil);
  if not Result then Exit;
  Result := (Video^.Scene^.Rate > 0) and (Video^.Scene^.Scale > 0) and
    not IsNan(StartSeconds) and not IsInfinite(StartSeconds) and
    not IsNan(PlaybackRatePercent) and not IsInfinite(PlaybackRatePercent);
  if not Result then Exit;
  // 配置先頭を0秒とし、入力プラグインや共有メモリの更新順に依存しない。
  // 負の開始位置は曲開始前の時間。0へ丸めず、未来ノートが発音位置へ近づく余白を作る。
  // 速度は現在値をローカル時間へ掛ける。速度アニメーションの積分は行わない。
  Seconds := StartSeconds + Double(Video^.Object_^.Frame) *
    Video^.Scene^.Scale / Video^.Scene^.Rate * PlaybackRatePercent / 100.0;
end;
end.

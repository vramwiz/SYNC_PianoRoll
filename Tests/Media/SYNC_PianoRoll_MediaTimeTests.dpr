program SYNC_PianoRoll_MediaTimeTests;

// 配置ごとの時刻計算を、分数fps・開始位置・停止・不正なシーンで検証する。
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Math,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SYNC_PianoRoll_MediaTime in 'Source\Plugin\Media\Timeline\SYNC_PianoRoll_MediaTime.pas';
var
  Video: TFILTER_PROC_VIDEO;
  Scene: TSCENE_INFO;
  Obj: TOBJECT_INFO;
  Seconds: Double;
procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;
begin
  FillChar(Video, SizeOf(Video), 0);
  FillChar(Scene, SizeOf(Scene), 0);
  FillChar(Obj, SizeOf(Obj), 0);
  Video.Scene := @Scene;
  Video.Object_ := @Obj;
  Scene.Rate := 30000;
  Scene.Scale := 1001;
  Obj.Frame := 300;
  Check(TryGetPianoRollMediaTime(@Video, 2, 200, Seconds) and
    SameValue(Seconds, 22.02, 0.000001), 'fractional fps / offset / speed');
  Check(TryGetPianoRollMediaTime(@Video, 2, 0, Seconds) and
    SameValue(Seconds, 2, 0.000001), 'zero speed');
  Obj.Frame := 0;
  Check(TryGetPianoRollMediaTime(@Video, 7, 100, Seconds) and
    SameValue(Seconds, 7, 0.000001), 'new object local origin');
  Scene.Rate := 30;
  Scene.Scale := 1;
  Check(TryGetPianoRollMediaTime(@Video, -5, 100, Seconds) and
    SameValue(Seconds, -5, 0.000001), 'negative start must not clamp to zero');
  Obj.Frame := 150;
  Check(TryGetPianoRollMediaTime(@Video, -5, 100, Seconds) and
    SameValue(Seconds, 0, 0.000001), 'negative start crossing zero');
  Obj.Frame := 180;
  Check(TryGetPianoRollMediaTime(@Video, -5, 100, Seconds) and
    SameValue(Seconds, 1, 0.000001), 'negative start after music begins');
  Obj.Frame := 75;
  Check(TryGetPianoRollMediaTime(@Video, -5, 200, Seconds) and
    SameValue(Seconds, 0, 0.000001), 'negative start with playback rate');
  Scene.Rate := 0;
  Check(not TryGetPianoRollMediaTime(@Video, 0, 100, Seconds), 'invalid fps');
  Scene.Rate := 30;
  Video.Scene := nil;
  Check(not TryGetPianoRollMediaTime(@Video, 0, 100, Seconds), 'missing scene');
  Check(not TryGetPianoRollMediaTime(nil, 0, 100, Seconds), 'missing video');
  Writeln('PASS');
end.

program SYNC_PianoRoll_StandaloneTimeTests;

// 単体フィルターへ渡されたローカル時刻の取得を検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_PianoRoll_FrameShared in 'Source\Common\Timeline\SYNC_PianoRoll_FrameShared.pas',
  SYNC_PianoRoll_ContextManager in 'Source\Common\Timeline\SYNC_PianoRoll_ContextManager.pas',
  SYNC_PianoRoll_Time in 'Source\Common\Timeline\SYNC_PianoRoll_Time.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  ObjectInfo: TOBJECT_INFO;
  TimeSeconds: Double;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Flag := OBJECT_INFO_FLAG_FILTER_OBJECT;
  ObjectInfo.Time := 10.5;
  ObjectInfo.FrameS := 300;
  ObjectInfo.Frame := 15;
  Video.Object_ := @ObjectInfo;

  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'standalone time could not be resolved');
  Check(Abs(TimeSeconds - 10.5) < 0.000001,
    'object local time mismatch');

  // 配置開始位置が変わっても、渡されたローカル時刻をそのまま使用する。
  ObjectInfo.Time := 0.5;
  ObjectInfo.FrameS := 600;
  ObjectInfo.Frame := 15;
  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'moved object time could not be resolved');
  Check(Abs(TimeSeconds - 0.5) < 0.000001,
    'object placement affected local time');

  // Input＋Filter方式では、メディアオブジェクトのローカル時刻ではなく
  // 入力設定の開始時間を含むInputフレームを音楽同期へ使用する。
  ObjectInfo.Flag := 0;
  ObjectInfo.ID := 100;
  ObjectInfo.EffectID := 200;
  ObjectInfo.Frame := 0;
  ObjectInfo.Time := 0.0;
  PublishPianoRollFrame(81, 30, 1);
  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'input time could not be resolved');
  Check(Abs(TimeSeconds - 2.7) < 0.000001,
    'input start time was not applied');

  // 同一入力フレームが再取得されない再描画も、ローカルフレーム差分で補間する。
  ObjectInfo.Frame := 1;
  ObjectInfo.Time := 1 / 30;
  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'interpolated input time could not be resolved');
  Check(Abs(TimeSeconds - (82 / 30)) < 0.000001,
    'input time interpolation mismatch');

  Video.Object_ := nil;
  Check(not TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'missing object was accepted');
  Writeln('PASS');
end.

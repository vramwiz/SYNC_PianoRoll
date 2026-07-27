program SYNC_PianoRoll_StandaloneTimeTests;

// 単体フィルターへ渡されたローカル時刻の取得を検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
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

  Video.Object_ := nil;
  Check(not TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'missing object was accepted');
  Writeln('PASS');
end.

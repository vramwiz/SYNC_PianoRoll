program SYNC_PianoRoll_FrameContextTests;

// 共有フレームとObject ID／Effect ID別のローカル補間を検証する。

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_PianoRoll_FrameShared in 'Source\Common\Timeline\SYNC_PianoRoll_FrameShared.pas',
  SYNC_PianoRoll_ContextManager in 'Source\Common\Timeline\SYNC_PianoRoll_ContextManager.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure SetObject(var ObjectInfo: TOBJECT_INFO; ObjectID, EffectID: Int64;
  Frame: Integer);
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  ObjectInfo.ID := ObjectID;
  ObjectInfo.EffectID := EffectID;
  ObjectInfo.Frame := Frame;
end;

procedure CheckResolved(var Video: TFILTER_PROC_VIDEO;
  const SharedState: TSyncPianoRollFrameState; PlaybackRatePercent: Double;
  ExpectedFrame: Integer; ExpectedTime: Double;
  const MessageText: string);
var
  EffectiveState: TSyncPianoRollFrameState;
begin
  Check(ResolvePianoRollFrameState(@Video, SharedState, PlaybackRatePercent,
    EffectiveState),
    MessageText + ': resolve failed');
  Check(EffectiveState.Frame = ExpectedFrame,
    Format('%s: expected frame %d, actual %d',
      [MessageText, ExpectedFrame, EffectiveState.Frame]));
  Check(SameValue(EffectiveState.TimeSeconds, ExpectedTime),
    MessageText + ': time mismatch');
end;

procedure TestSharedMemory;
var
  State: TSyncPianoRollFrameState;
begin
  PublishPianoRollFrame(45, 30, 1);
  Check(TryReadPianoRollFrame(State), 'shared frame read failed');
  Check(State.Frame = 45, 'shared frame mismatch');
  Check((State.Rate = 30) and (State.Scale = 1),
    'shared time base mismatch');
  Check(SameValue(State.TimeSeconds, 1.5), 'shared seconds mismatch');
  Check(not Odd(State.Sequence), 'shared sequence must be stable');
end;

procedure TestObjectContexts;
var
  ObjectA, ObjectB, ObjectAEffect2: TOBJECT_INFO;
  SharedState: TSyncPianoRollFrameState;
  VideoA, VideoB, VideoAEffect2: TFILTER_PROC_VIDEO;
begin
  FillChar(VideoA, SizeOf(VideoA), 0);
  FillChar(VideoB, SizeOf(VideoB), 0);
  FillChar(VideoAEffect2, SizeOf(VideoAEffect2), 0);
  FillChar(SharedState, SizeOf(SharedState), 0);
  SharedState.Sequence := 2;
  SharedState.Frame := 90;
  SharedState.Rate := 30;
  SharedState.Scale := 1;
  SharedState.UpdateTick := GetTickCount64;

  SetObject(ObjectA, 1, 10, 10);
  SetObject(ObjectB, 2, 10, 50);
  SetObject(ObjectAEffect2, 1, 11, 20);
  VideoA.Object_ := @ObjectA;
  VideoB.Object_ := @ObjectB;
  VideoAEffect2.Object_ := @ObjectAEffect2;

  CheckResolved(VideoA, SharedState, 100, 90, 3.0, 'object A anchor');
  CheckResolved(VideoB, SharedState, 100, 90, 3.0, 'object B anchor');
  CheckResolved(VideoAEffect2, SharedState, 100, 90, 3.0,
    'effect 2 anchor');

  // Inputの共有更新が止まっても、各ローカルフレーム差分で補間する。
  ObjectA.Frame := 11;
  ObjectB.Frame := 51;
  ObjectAEffect2.Frame := 21;
  CheckResolved(VideoA, SharedState, 100, 91, 91 / 30,
    'object A interpolation');
  CheckResolved(VideoB, SharedState, 100, 91, 91 / 30,
    'object B interpolation');
  CheckResolved(VideoAEffect2, SharedState, 100, 91, 91 / 30,
    'effect 2 interpolation');

  // GUI値だけが変わっても、Inputの新しい共有更新までは基準速度を維持する。
  ObjectA.Frame := 12;
  CheckResolved(VideoA, SharedState, 200, 92, 92 / 30,
    'speed change before input refresh');

  // 新しい共有更新番号を受信したら、その時点の再生速度で再基準化する。
  SharedState.Sequence := 4;
  SharedState.Frame := 120;
  SharedState.UpdateTick := GetTickCount64;
  CheckResolved(VideoA, SharedState, 200, 120, 4.0, 'object A re-anchor');
  ObjectA.Frame := 13;
  CheckResolved(VideoA, SharedState, 200, 122, 122 / 30,
    'object A after speed re-anchor');

  // Aの再基準化が、まだ新しい共有値を処理していないBへ混入しない。
  ObjectB.Frame := 52;
  CheckResolved(VideoB, SharedState, 200, 120, 4.0,
    'object B independent re-anchor');

  // 100%未満では整数Frameが同じでも、実数時刻は指定倍率で連続して進む。
  SharedState.Sequence := 6;
  SharedState.Frame := 150;
  SharedState.UpdateTick := GetTickCount64;
  ObjectA.Frame := 14;
  CheckResolved(VideoA, SharedState, 50, 150, 5.0,
    'half speed re-anchor');
  ObjectA.Frame := 15;
  CheckResolved(VideoA, SharedState, 50, 150, 150.5 / 30,
    'half speed fractional interpolation');
end;

begin
  InitializePianoRollFrameShared;
  InitializePianoRollContexts;
  try
    TestSharedMemory;
    TestObjectContexts;
    Writeln('PASS');
  finally
    FinalizePianoRollContexts;
    FinalizePianoRollFrameShared;
  end;
end.

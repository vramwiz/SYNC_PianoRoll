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
  const SharedState: TSyncPianoRollFrameState; ExpectedFrame: Integer;
  const MessageText: string);
var
  EffectiveState: TSyncPianoRollFrameState;
begin
  Check(ResolvePianoRollFrameState(@Video, SharedState, EffectiveState),
    MessageText + ': resolve failed');
  Check(EffectiveState.Frame = ExpectedFrame,
    Format('%s: expected frame %d, actual %d',
      [MessageText, ExpectedFrame, EffectiveState.Frame]));
  Check(SameValue(EffectiveState.TimeSeconds,
    ExpectedFrame * EffectiveState.Scale / EffectiveState.Rate),
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

  CheckResolved(VideoA, SharedState, 90, 'object A anchor');
  CheckResolved(VideoB, SharedState, 90, 'object B anchor');
  CheckResolved(VideoAEffect2, SharedState, 90, 'effect 2 anchor');

  // Inputの共有更新が止まっても、各ローカルフレーム差分で補間する。
  ObjectA.Frame := 11;
  ObjectB.Frame := 51;
  ObjectAEffect2.Frame := 21;
  CheckResolved(VideoA, SharedState, 91, 'object A interpolation');
  CheckResolved(VideoB, SharedState, 91, 'object B interpolation');
  CheckResolved(VideoAEffect2, SharedState, 91, 'effect 2 interpolation');

  // 新しい共有更新番号を受信したら、各コンテキストを個別に再基準化する。
  SharedState.Sequence := 4;
  SharedState.Frame := 120;
  SharedState.UpdateTick := GetTickCount64;
  ObjectA.Frame := 12;
  CheckResolved(VideoA, SharedState, 120, 'object A re-anchor');
  ObjectA.Frame := 13;
  CheckResolved(VideoA, SharedState, 121, 'object A after re-anchor');

  // Aの再基準化が、まだ新しい共有値を処理していないBへ混入しない。
  ObjectB.Frame := 52;
  CheckResolved(VideoB, SharedState, 120, 'object B independent re-anchor');
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

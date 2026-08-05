unit SYNC_PianoRoll_ContextManager;

// InputのフレームとFilterのローカルフレームをObject ID＋Effect IDごとに対応付ける。

interface

uses
  AviUtl2FilterTypes,
  SYNC_PianoRoll_FrameShared;

procedure InitializePianoRollContexts;
procedure FinalizePianoRollContexts;
function ResolvePianoRollFrameState(Video: PFILTER_PROC_VIDEO;
  const SharedState: TSyncPianoRollFrameState; PlaybackRatePercent: Double;
  out EffectiveState: TSyncPianoRollFrameState): Boolean;

implementation

uses
  Winapi.Windows,
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils;

const
  // 別オブジェクトや過去のプロジェクトが残した共有値を新規基準に採用しない。
  MAX_SHARED_FRAME_AGE_MS = 1000;

type
  TPianoRollObjectContext = class
  public
    ObjectID: Int64;
    EffectID: Int64;
    HasAnchor: Boolean;
    LastSharedSequence: Integer;
    AnchorSharedFrame: Integer;
    AnchorObjectFrame: Integer;
    Rate: Integer;
    Scale: Integer;
    PlaybackRatePercent: Double;
    UpdateTick: UInt64;
  end;

  TPianoRollContextList = class
  private
    FItems: TObjectList<TPianoRollObjectContext>;
    FLock: TCriticalSection;
    function FindByKey(ObjectID, EffectID: Int64): TPianoRollObjectContext;
    function GetOrCreate(ObjectID, EffectID: Int64): TPianoRollObjectContext;
  public
    constructor Create;
    destructor Destroy; override;
    function Resolve(Video: PFILTER_PROC_VIDEO;
      const SharedState: TSyncPianoRollFrameState; PlaybackRatePercent: Double;
      out EffectiveState: TSyncPianoRollFrameState): Boolean;
  end;

var
  PianoRollContexts: TPianoRollContextList;

constructor TPianoRollContextList.Create;
begin
  inherited Create;
  FItems := TObjectList<TPianoRollObjectContext>.Create(True);
  FLock := TCriticalSection.Create;
end;

destructor TPianoRollContextList.Destroy;
begin
  FLock.Free;
  FItems.Free;
  inherited Destroy;
end;

function TPianoRollContextList.FindByKey(ObjectID,
  EffectID: Int64): TPianoRollObjectContext;
var
  Context: TPianoRollObjectContext;
begin
  Result := nil;
  for Context in FItems do
    if (Context.ObjectID = ObjectID) and (Context.EffectID = EffectID) then
      Exit(Context);
end;

function TPianoRollContextList.GetOrCreate(ObjectID,
  EffectID: Int64): TPianoRollObjectContext;
begin
  Result := FindByKey(ObjectID, EffectID);
  if Result <> nil then
    Exit;

  Result := TPianoRollObjectContext.Create;
  Result.ObjectID := ObjectID;
  Result.EffectID := EffectID;
  Result.HasAnchor := False;
  FItems.Add(Result);
end;

function TPianoRollContextList.Resolve(Video: PFILTER_PROC_VIDEO;
  const SharedState: TSyncPianoRollFrameState; PlaybackRatePercent: Double;
  out EffectiveState: TSyncPianoRollFrameState): Boolean;
var
  Context: TPianoRollObjectContext;
  FrameDelta: Integer;
  ObjectInfo: POBJECT_INFO;
  SharedStateIsFresh: Boolean;
begin
  FillChar(EffectiveState, SizeOf(EffectiveState), 0);
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  ObjectInfo := Video^.Object_;
  FLock.Acquire;
  try
    Context := GetOrCreate(ObjectInfo^.ID, ObjectInfo^.EffectID);
    SharedStateIsFresh := (SharedState.UpdateTick > 0) and
      (GetTickCount64 - SharedState.UpdateTick <= MAX_SHARED_FRAME_AGE_MS);

    // Inputが発火した時点の共有絶対フレームとローカルフレームを対応付ける。
    // Inputの再取得が省略された再描画では、既存基準からローカル差分を補間する。
    if (not Context.HasAnchor and SharedStateIsFresh) or
      (Context.HasAnchor and SharedStateIsFresh and
       (Context.LastSharedSequence <> SharedState.Sequence)) then
    begin
      Context.HasAnchor := True;
      Context.LastSharedSequence := SharedState.Sequence;
      Context.AnchorSharedFrame := SharedState.Frame;
      Context.AnchorObjectFrame := ObjectInfo^.Frame;
      Context.Rate := SharedState.Rate;
      Context.Scale := SharedState.Scale;
      if PlaybackRatePercent > 0 then
        Context.PlaybackRatePercent := PlaybackRatePercent
      else
        Context.PlaybackRatePercent := 100.0;
      Context.UpdateTick := SharedState.UpdateTick;
    end;

    if not Context.HasAnchor or (Context.Rate <= 0) or
      (Context.Scale <= 0) or (Context.PlaybackRatePercent <= 0) then
      Exit;

    FrameDelta := ObjectInfo^.Frame - Context.AnchorObjectFrame;
    EffectiveState := SharedState;
    EffectiveState.Sequence := Context.LastSharedSequence;
    EffectiveState.Frame := Context.AnchorSharedFrame +
      Round(FrameDelta * Context.PlaybackRatePercent / 100.0);
    EffectiveState.Rate := Context.Rate;
    EffectiveState.Scale := Context.Scale;
    // 低速時も整数フレームへの丸めで時刻が段階的にならないよう、
    // 基準時刻へローカルフレーム差分と再生倍率を実数のまま加算する。
    EffectiveState.TimeSeconds := Context.AnchorSharedFrame *
      Context.Scale / Context.Rate + FrameDelta * Context.Scale /
      Context.Rate * Context.PlaybackRatePercent / 100.0;
    EffectiveState.UpdateTick := Context.UpdateTick;
    Result := True;
  finally
    FLock.Release;
  end;
end;

procedure InitializePianoRollContexts;
begin
  if PianoRollContexts <> nil then
    Exit;
  try
    PianoRollContexts := TPianoRollContextList.Create;
  except
    FreeAndNil(PianoRollContexts);
  end;
end;

procedure FinalizePianoRollContexts;
begin
  FreeAndNil(PianoRollContexts);
end;

function ResolvePianoRollFrameState(Video: PFILTER_PROC_VIDEO;
  const SharedState: TSyncPianoRollFrameState; PlaybackRatePercent: Double;
  out EffectiveState: TSyncPianoRollFrameState): Boolean;
begin
  InitializePianoRollContexts;
  Result := (PianoRollContexts <> nil) and
    PianoRollContexts.Resolve(Video, SharedState, PlaybackRatePercent,
      EffectiveState);
end;

initialization
  PianoRollContexts := nil;

finalization
  FinalizePianoRollContexts;

end.

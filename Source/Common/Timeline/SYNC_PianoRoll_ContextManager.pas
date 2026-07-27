unit SYNC_PianoRoll_ContextManager;

// 旧共有フレーム経路の互換確認用に、Object ID + Effect ID ごとの時刻基準を保持する。

interface

uses
  AviUtl2FilterTypes,
  SYNC_PianoRoll_FrameShared;

procedure InitializePianoRollContexts;
procedure FinalizePianoRollContexts;
function ResolvePianoRollFrameState(Video: PFILTER_PROC_VIDEO;
  const SharedState: TSyncPianoRollFrameState;
  out EffectiveState: TSyncPianoRollFrameState): Boolean;

implementation

uses
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils;

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
      const SharedState: TSyncPianoRollFrameState;
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
  const SharedState: TSyncPianoRollFrameState;
  out EffectiveState: TSyncPianoRollFrameState): Boolean;
var
  Context: TPianoRollObjectContext;
  ObjectInfo: POBJECT_INFO;
begin
  FillChar(EffectiveState, SizeOf(EffectiveState), 0);
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  ObjectInfo := Video^.Object_;
  FLock.Acquire;
  try
    Context := GetOrCreate(ObjectInfo^.ID, ObjectInfo^.EffectID);

    // Inputが発火した時点の共有絶対フレームとローカルフレームを対応付ける。
    if not Context.HasAnchor or
      (Context.LastSharedSequence <> SharedState.Sequence) then
    begin
      Context.HasAnchor := True;
      Context.LastSharedSequence := SharedState.Sequence;
      Context.AnchorSharedFrame := SharedState.Frame;
      Context.AnchorObjectFrame := ObjectInfo^.Frame;
      Context.Rate := SharedState.Rate;
      Context.Scale := SharedState.Scale;
      Context.UpdateTick := SharedState.UpdateTick;
    end;

    if not Context.HasAnchor or (Context.Rate <= 0) or
      (Context.Scale <= 0) then
      Exit;

    EffectiveState := SharedState;
    EffectiveState.Sequence := Context.LastSharedSequence;
    EffectiveState.Frame := Context.AnchorSharedFrame +
      (ObjectInfo^.Frame - Context.AnchorObjectFrame);
    EffectiveState.Rate := Context.Rate;
    EffectiveState.Scale := Context.Scale;
    EffectiveState.TimeSeconds := EffectiveState.Frame *
      Context.Scale / Context.Rate;
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
  const SharedState: TSyncPianoRollFrameState;
  out EffectiveState: TSyncPianoRollFrameState): Boolean;
begin
  InitializePianoRollContexts;
  Result := (PianoRollContexts <> nil) and
    PianoRollContexts.Resolve(Video, SharedState, EffectiveState);
end;

initialization
  PianoRollContexts := nil;

finalization
  FinalizePianoRollContexts;

end.

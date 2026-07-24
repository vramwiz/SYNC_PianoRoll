unit SYNC_PianoRoll_Renderer;

// Object ID + Effect IDごとのRGBAバッファを管理し、選択された表示実装へ渡す。

interface

uses
  AviUtl2FilterTypes,
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_MusicData;

procedure InitializePianoRollRenderer;
procedure FinalizePianoRollRenderer;
function RenderPianoRoll(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Display: IPianoRollDisplay;
  const Settings: TPianoRollDisplaySettings): Boolean;

implementation

uses
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils,
  SYNC_PianoRoll_RGBA;

const
  MAX_RENDER_DIMENSION = 16384;

type
  TPianoRollRenderContext = class
  public
    ObjectID: Int64;
    EffectID: Int64;
    Buffer: PPIXEL_RGBA;
    BufferSize: NativeInt;
    Lock: TCriticalSection;
    constructor Create;
    destructor Destroy; override;
  end;

  TPianoRollRenderContextList = class
  private
    FItems: TObjectList<TPianoRollRenderContext>;
    FLock: TCriticalSection;
    function FindByKey(ObjectID, EffectID: Int64): TPianoRollRenderContext;
  public
    constructor Create;
    destructor Destroy; override;
    function GetOrCreate(ObjectID, EffectID: Int64): TPianoRollRenderContext;
  end;

var
  RenderContexts: TPianoRollRenderContextList;

constructor TPianoRollRenderContext.Create;
begin
  inherited Create;
  Buffer := nil;
  BufferSize := 0;
  Lock := TCriticalSection.Create;
end;

destructor TPianoRollRenderContext.Destroy;
begin
  if Buffer <> nil then
    FreeMem(Buffer);
  Lock.Free;
  inherited Destroy;
end;

constructor TPianoRollRenderContextList.Create;
begin
  inherited Create;
  FItems := TObjectList<TPianoRollRenderContext>.Create(True);
  FLock := TCriticalSection.Create;
end;

destructor TPianoRollRenderContextList.Destroy;
begin
  FLock.Free;
  FItems.Free;
  inherited Destroy;
end;

function TPianoRollRenderContextList.FindByKey(ObjectID,
  EffectID: Int64): TPianoRollRenderContext;
var
  Context: TPianoRollRenderContext;
begin
  Result := nil;
  for Context in FItems do
    if (Context.ObjectID = ObjectID) and (Context.EffectID = EffectID) then
      Exit(Context);
end;

function TPianoRollRenderContextList.GetOrCreate(ObjectID,
  EffectID: Int64): TPianoRollRenderContext;
begin
  FLock.Acquire;
  try
    Result := FindByKey(ObjectID, EffectID);
    if Result <> nil then
      Exit;
    Result := TPianoRollRenderContext.Create;
    Result.ObjectID := ObjectID;
    Result.EffectID := EffectID;
    FItems.Add(Result);
  finally
    FLock.Release;
  end;
end;

function EnsureBuffer(Context: TPianoRollRenderContext;
  RequiredSize: NativeInt): Boolean;
begin
  Result := False;
  if RequiredSize <= 0 then
    Exit;
  if Context.BufferSize <> RequiredSize then
  begin
    ReallocMem(Context.Buffer, RequiredSize);
    Context.BufferSize := RequiredSize;
  end;
  Result := Context.Buffer <> nil;
end;

procedure InitializePianoRollRenderer;
begin
  if RenderContexts <> nil then
    Exit;
  try
    RenderContexts := TPianoRollRenderContextList.Create;
  except
    FreeAndNil(RenderContexts);
  end;
end;

procedure FinalizePianoRollRenderer;
begin
  FreeAndNil(RenderContexts);
end;

function RenderPianoRoll(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Display: IPianoRollDisplay;
  const Settings: TPianoRollDisplaySettings): Boolean;
var
  BufferSize64: Int64;
  Canvas: TPianoRollCanvas;
  Context: TPianoRollRenderContext;
  Height, Width: Integer;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or
    not Assigned(Video^.SetImageData) or not Assigned(Data) or
    not Assigned(Display) then
    Exit;

  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) or
    (Width > MAX_RENDER_DIMENSION) or (Height > MAX_RENDER_DIMENSION) then
    Exit;
  BufferSize64 := Int64(Width) * Height * SizeOf(TPIXEL_RGBA);
  if (BufferSize64 <= 0) or (BufferSize64 > MaxInt) then
    Exit;

  InitializePianoRollRenderer;
  if RenderContexts = nil then
    Exit;
  Context := RenderContexts.GetOrCreate(Video^.Object_^.ID,
    Video^.Object_^.EffectID);
  if Context = nil then
    Exit;

  Context.Lock.Acquire;
  try
    if not EnsureBuffer(Context, BufferSize64) then
      Exit;
    Canvas.Initialize(Context.Buffer, Width, Height);
    Canvas.Clear;
    Display.Draw(Canvas, Data, TimeSeconds, Settings);
    Video^.SetImageData(Context.Buffer, Width, Height);
    Result := True;
  finally
    Context.Lock.Release;
  end;
end;

initialization
  RenderContexts := nil;

finalization
  FinalizePianoRollRenderer;

end.

unit SYNC_PianoRoll_FrameShared;

// Input と Filter のDLL間で現在フレームを受け渡す共通の共有領域。
// 画像サイズはFilterの処理対象から取得するため、この領域では共有しない。

interface

type
  PSyncPianoRollFrameState = ^TSyncPianoRollFrameState;
  TSyncPianoRollFrameState = record
    Magic: Cardinal;
    Version: Cardinal;
    Sequence: Integer;
    Frame: Integer;
    Rate: Integer;
    Scale: Integer;
    TimeSeconds: Double;
    UpdateTick: UInt64;
  end;

procedure InitializePianoRollFrameShared;
procedure FinalizePianoRollFrameShared;
procedure PublishPianoRollFrame(Frame, Rate, Scale: Integer);
function TryReadPianoRollFrame(out State: TSyncPianoRollFrameState): Boolean;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  SharedMemoryBase;

const
  PIANOROLL_FRAME_MAP_NAME = 'Local\SYNC_PianoRoll_Frame_V1';
  PIANOROLL_FRAME_MAGIC = $53505246; // SPRF
  PIANOROLL_FRAME_VERSION = 1;

var
  SharedMemory: TSharedMemoryBase;

function GetMapView: PSyncPianoRollFrameState;
begin
  if SharedMemory = nil then
    Exit(nil);
  Result := SharedMemory.View;
end;

procedure InitializePianoRollFrameShared;
begin
  if SharedMemory <> nil then
    Exit;

  try
    SharedMemory := TSharedMemoryBase.Create(PIANOROLL_FRAME_MAP_NAME,
      SizeOf(TSyncPianoRollFrameState));
  except
    FreeAndNil(SharedMemory);
  end;
end;

procedure FinalizePianoRollFrameShared;
begin
  FreeAndNil(SharedMemory);
end;

procedure PublishPianoRollFrame(Frame, Rate, Scale: Integer);
var
  MapView: PSyncPianoRollFrameState;
  SequenceBefore: Integer;
  WriteSequence: Integer;
  Retry: Integer;
begin
  InitializePianoRollFrameShared;
  MapView := GetMapView;
  if MapView = nil then
    Exit;

  // 偶数から奇数へ変更できたInputだけが書き込む。
  WriteSequence := 0;
  for Retry := 0 to 15 do
  begin
    SequenceBefore := InterlockedCompareExchange(MapView^.Sequence, 0, 0);
    if Odd(SequenceBefore) then
      Continue;
    if InterlockedCompareExchange(MapView^.Sequence, SequenceBefore + 1,
      SequenceBefore) = SequenceBefore then
    begin
      WriteSequence := SequenceBefore + 1;
      Break;
    end;
  end;
  if WriteSequence = 0 then
    Exit;

  MapView^.Magic := PIANOROLL_FRAME_MAGIC;
  MapView^.Version := PIANOROLL_FRAME_VERSION;
  MapView^.Frame := Frame;
  MapView^.Rate := Rate;
  MapView^.Scale := Scale;
  if (Rate > 0) and (Scale > 0) then
    MapView^.TimeSeconds := Frame * Scale / Rate
  else
    MapView^.TimeSeconds := 0;
  MapView^.UpdateTick := GetTickCount64;
  InterlockedExchange(MapView^.Sequence, WriteSequence + 1);
end;

function TryReadPianoRollFrame(out State: TSyncPianoRollFrameState): Boolean;
var
  MapView: PSyncPianoRollFrameState;
  SequenceBefore, SequenceAfter: Integer;
  Retry: Integer;
begin
  FillChar(State, SizeOf(State), 0);
  InitializePianoRollFrameShared;
  MapView := GetMapView;
  Result := False;
  if MapView = nil then
    Exit;

  // Inputの更新と重なった場合は短く再試行し、一貫した組だけを返す。
  for Retry := 0 to 2 do
  begin
    SequenceBefore := InterlockedCompareExchange(MapView^.Sequence, 0, 0);
    if Odd(SequenceBefore) then
      Continue;

    State := MapView^;
    SequenceAfter := InterlockedCompareExchange(MapView^.Sequence, 0, 0);
    Result := (SequenceBefore = SequenceAfter) and
      not Odd(SequenceAfter) and
      (State.Magic = PIANOROLL_FRAME_MAGIC) and
      (State.Version = PIANOROLL_FRAME_VERSION);
    if Result then
      Exit;
  end;

  FillChar(State, SizeOf(State), 0);
end;

initialization
  SharedMemory := nil;

finalization
  FinalizePianoRollFrameShared;

end.

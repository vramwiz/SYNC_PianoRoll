unit SYNC_PianoRoll_PitchFollow;

// 発音中または直近未来のノートから、表示タイプ共通の実効音域を決定する。

interface

uses
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_PianoKeys;

procedure ResolveEffectivePianoRollPitchRange(
  const Data: IPianoRollMusicData; TimeSeconds, DisplayTime: Double;
  CenterNote, VisibleNoteCount: Integer;
  FollowMode: TPianoRollPitchFollowMode;
  KeyboardType: TPianoRollKeyboardType;
  out LowestNote, HighestNote: Integer);

implementation

uses
  System.Math;

const
  NOTE_TIME_EPSILON = 1.0E-6;

function GetNoteEndSeconds(const Note: TPianoRollNoteData): Double;
begin
  Result := Note.EndSeconds;
  if Result < Note.StartSeconds then
    Result := Note.StartSeconds + 0.2;
end;

procedure IncludeNoteKey(Key: Integer; var Found: Boolean;
  var LowestNote, HighestNote: Integer);
begin
  if (Key < 0) or (Key > 127) then
    Exit;
  if not Found then
  begin
    LowestNote := Key;
    HighestNote := Key;
    Found := True;
  end
  else
  begin
    LowestNote := Min(LowestNote, Key);
    HighestNote := Max(HighestNote, Key);
  end;
end;

function TryResolveFollowTarget(const Data: IPianoRollMusicData;
  TimeSeconds, DisplayTime: Double; KeyboardType: TPianoRollKeyboardType;
  out LowestNote, HighestNote: Integer): Boolean;
var
  EarliestFuture: Double;
  I: Integer;
  Note: TPianoRollNoteData;
begin
  Result := False;
  if not Assigned(Data) then
    Exit;

  // 和音を一つの対象として扱うため、発音中の全ノートから音域を求める。
  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsPianoRollKeyVisible(Note.Key, KeyboardType) then
      Continue;
    if (Note.StartSeconds <= TimeSeconds + NOTE_TIME_EPSILON) and
      (GetNoteEndSeconds(Note) >= TimeSeconds - NOTE_TIME_EPSILON) then
      IncludeNoteKey(Note.Key, Result, LowestNote, HighestNote);
  end;
  if Result then
    Exit;

  // 無音時は表示中の直近未来ノートを先読みし、遠い無音区間では基準音域へ戻す。
  EarliestFuture := MaxDouble;
  DisplayTime := Max(0.0, DisplayTime);
  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsPianoRollKeyVisible(Note.Key, KeyboardType) then
      Continue;
    if (Note.StartSeconds >= TimeSeconds - NOTE_TIME_EPSILON) and
      (Note.StartSeconds <= TimeSeconds + DisplayTime + NOTE_TIME_EPSILON) then
      EarliestFuture := Min(EarliestFuture, Note.StartSeconds);
  end;
  if EarliestFuture = MaxDouble then
    Exit;

  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsPianoRollKeyVisible(Note.Key, KeyboardType) then
      Continue;
    if Abs(Note.StartSeconds - EarliestFuture) <= NOTE_TIME_EPSILON then
      IncludeNoteKey(Note.Key, Result, LowestNote, HighestNote);
  end;
end;

procedure ResolveEffectivePianoRollPitchRange(
  const Data: IPianoRollMusicData; TimeSeconds, DisplayTime: Double;
  CenterNote, VisibleNoteCount: Integer;
  FollowMode: TPianoRollPitchFollowMode;
  KeyboardType: TPianoRollKeyboardType;
  out LowestNote, HighestNote: Integer);
var
  BaseHighest, BaseLowest: Integer;
  FollowCenter, FollowHighest, FollowLowest: Integer;
  MaximumLowest, RangeWidth: Integer;
begin
  VisibleNoteCount := EnsureRange(VisibleNoteCount, 1, 128);
  ResolvePianoRollPitchRange(CenterNote, VisibleNoteCount,
    BaseLowest, BaseHighest);
  LowestNote := BaseLowest;
  HighestNote := BaseHighest;
  if (FollowMode = ppfmNone) or
    not TryResolveFollowTarget(Data, TimeSeconds, DisplayTime, KeyboardType,
      FollowLowest, FollowHighest) then
    Exit;

  // 表示幅より広い和音は全音を収められないため、その中央を優先する。
  RangeWidth := FollowHighest - FollowLowest + 1;
  if (FollowMode = ppfmAlways) or (RangeWidth > VisibleNoteCount) then
  begin
    FollowCenter := (FollowLowest + FollowHighest + 1) div 2;
    ResolvePianoRollPitchRange(FollowCenter, VisibleNoteCount,
      LowestNote, HighestNote);
    Exit;
  end;

  if FollowLowest < LowestNote then
    LowestNote := FollowLowest;
  if FollowHighest > HighestNote then
    LowestNote := FollowHighest - VisibleNoteCount + 1;
  MaximumLowest := 128 - VisibleNoteCount;
  LowestNote := EnsureRange(LowestNote, 0, MaximumLowest);
  HighestNote := LowestNote + VisibleNoteCount - 1;
end;

end.

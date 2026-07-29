program SYNC_PianoRoll_PitchFollowTests;

// 音域追従の対象選択、移動規則、MIDI範囲端の補正を検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  SYNC_PianoRoll_MusicData in 'Source\Common\Data\SYNC_PianoRoll_MusicData.pas',
  SYNC_PianoRoll_PianoKeys in 'Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas',
  SYNC_PianoRoll_Colors in 'Source\Common\Color\SYNC_PianoRoll_Colors.pas',
  SYNC_PianoRoll_RGBA in 'Source\Common\Render\SYNC_PianoRoll_RGBA.pas',
  SYNC_PianoRoll_DisplayTypes in 'Source\Common\Layout\SYNC_PianoRoll_DisplayTypes.pas',
  SYNC_PianoRoll_PitchFollow in 'Source\Common\Layout\SYNC_PianoRoll_PitchFollow.pas';

type
  TMockMusicData = class(TInterfacedObject, IPianoRollMusicData)
  private
    FNotes: TArray<TPianoRollNoteData>;
  public
    constructor Create(const Keys: array of Integer;
      const Starts, Ends: array of Double);
    function GetFileName: string;
    function GetLengthSeconds: Double;
    function GetNoteCount: Integer;
    function GetNote(Index: Integer): TPianoRollNoteData;
    function GetBeatCount: Integer;
    function GetBeat(Index: Integer): TPianoRollBeatData;
    function GetTrackCount: Integer;
    function GetTrack(Index: Integer): TPianoRollTrackData;
  end;

procedure CheckRange(const Data: IPianoRollMusicData;
  TimeSeconds, DisplayTime: Double; CenterNote, VisibleNoteCount: Integer;
  FollowMode: TPianoRollPitchFollowMode;
  ExpectedLowest, ExpectedHighest: Integer; const MessageText: string);
var
  Highest, Lowest: Integer;
begin
  ResolveEffectivePianoRollPitchRange(Data, TimeSeconds, DisplayTime,
    CenterNote, VisibleNoteCount, FollowMode, pktPiano, Lowest, Highest);
  if (Lowest <> ExpectedLowest) or (Highest <> ExpectedHighest) then
    raise Exception.CreateFmt('%s: expected %d..%d, got %d..%d',
      [MessageText, ExpectedLowest, ExpectedHighest, Lowest, Highest]);
end;

constructor TMockMusicData.Create(const Keys: array of Integer;
  const Starts, Ends: array of Double);
var
  I: Integer;
begin
  inherited Create;
  if (Length(Keys) <> Length(Starts)) or (Length(Keys) <> Length(Ends)) then
    raise EArgumentException.Create('note array length mismatch');
  SetLength(FNotes, Length(Keys));
  for I := 0 to High(Keys) do
  begin
    FNotes[I].Key := Keys[I];
    FNotes[I].StartSeconds := Starts[I];
    FNotes[I].EndSeconds := Ends[I];
  end;
end;

function TMockMusicData.GetFileName: string;
begin
  Result := 'mock.mid';
end;

function TMockMusicData.GetLengthSeconds: Double;
begin
  Result := 10.0;
end;

function TMockMusicData.GetNoteCount: Integer;
begin
  Result := Length(FNotes);
end;

function TMockMusicData.GetNote(Index: Integer): TPianoRollNoteData;
begin
  Result := FNotes[Index];
end;

function TMockMusicData.GetBeatCount: Integer;
begin
  Result := 0;
end;

function TMockMusicData.GetBeat(Index: Integer): TPianoRollBeatData;
begin
  raise ERangeError.Create('beat index');
end;

function TMockMusicData.GetTrackCount: Integer;
begin
  Result := 0;
end;

function TMockMusicData.GetTrack(Index: Integer): TPianoRollTrackData;
begin
  raise ERangeError.Create('track index');
end;

var
  AccidentalNote, ActiveChord, FutureChord, HighNote,
  LowNote: IPianoRollMusicData;
  Highest, Lowest: Integer;
begin
  AccidentalNote := TMockMusicData.Create([121], [0.0], [2.0]);
  ActiveChord := TMockMusicData.Create([36, 48], [0.0, 0.0], [2.0, 2.0]);
  FutureChord := TMockMusicData.Create([84, 88, 40],
    [2.0, 2.0, 4.0], [3.0, 3.0, 5.0]);
  HighNote := TMockMusicData.Create([120], [0.0], [2.0]);
  LowNote := TMockMusicData.Create([2], [0.0], [2.0]);

  CheckRange(HighNote, 1.0, 4.0, 64, 12, ppfmNone,
    58, 69, 'none keeps the base range');
  CheckRange(ActiveChord, 1.0, 4.0, 64, 12, ppfmAlways,
    36, 47, 'always centers an active chord');
  CheckRange(HighNote, 1.0, 4.0, 64, 12, ppfmOnOverflow,
    109, 120, 'overflow follows upward by the minimum distance');
  CheckRange(LowNote, 1.0, 4.0, 64, 12, ppfmOnOverflow,
    2, 13, 'overflow follows downward by the minimum distance');
  CheckRange(FutureChord, 1.0, 4.0, 64, 12, ppfmAlways,
    80, 91, 'nearest future chord is followed');
  CheckRange(FutureChord, -10.0, 4.0, 64, 12, ppfmAlways,
    58, 69, 'distant future notes do not move the base range');
  CheckRange(HighNote, 1.0, 4.0, 64, 20, ppfmAlways,
    108, 127, 'upper MIDI edge keeps the requested width');
  ResolveEffectivePianoRollPitchRange(AccidentalNote, 1.0, 4.0,
    64, 12, ppfmAlways, pktHarp7, Lowest, Highest);
  if (Lowest <> 58) or (Highest <> 69) then
    raise Exception.Create('harp follow must ignore accidental notes');

  Writeln('PASS');
end.

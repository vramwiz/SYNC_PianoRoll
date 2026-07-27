unit SYNC_PianoRoll_PianoKeys;

// MIDIキーの白鍵・黒鍵判定と、白鍵単位の音階方向位置を提供する。

interface

function IsPianoBlackKey(MidiKey: Integer): Boolean;
function GetPianoKeyPitchCenter(MidiKey: Integer): Double;
procedure ResolvePianoRollPitchRange(CenterNote, VisibleNoteCount: Integer;
  out LowestNote, HighestNote: Integer);

implementation

uses
  System.Math;

const
  // 各キーの中心位置。1.0が白鍵1個分の音階方向距離を表す。
  PITCH_CENTER_IN_OCTAVE: array[0..11] of Double = (
    0.5, 1.0, 1.5, 2.0, 2.5, 3.5,
    4.0, 4.5, 5.0, 5.5, 6.0, 6.5
  );

function IsPianoBlackKey(MidiKey: Integer): Boolean;
var
  PitchClass: Integer;
begin
  PitchClass := MidiKey mod 12;
  if PitchClass < 0 then
    Inc(PitchClass, 12);
  Result := PitchClass in [1, 3, 6, 8, 10];
end;

function GetPianoKeyPitchCenter(MidiKey: Integer): Double;
var
  OctaveIndex, PitchClass: Integer;
begin
  OctaveIndex := MidiKey div 12;
  PitchClass := MidiKey mod 12;
  if PitchClass < 0 then
  begin
    Inc(PitchClass, 12);
    Dec(OctaveIndex);
  end;
  Result := OctaveIndex * 7.0 + PITCH_CENTER_IN_OCTAVE[PitchClass];
end;

procedure ResolvePianoRollPitchRange(CenterNote, VisibleNoteCount: Integer;
  out LowestNote, HighestNote: Integer);
begin
  CenterNote := EnsureRange(CenterNote, 0, 127);
  VisibleNoteCount := EnsureRange(VisibleNoteCount, 1, 128);

  // 偶数個では中央ノートを上側の中央とし、常に指定個数を維持する。
  LowestNote := CenterNote - VisibleNoteCount div 2;
  HighestNote := LowestNote + VisibleNoteCount - 1;
  if LowestNote < 0 then
  begin
    LowestNote := 0;
    HighestNote := VisibleNoteCount - 1;
  end
  else if HighestNote > 127 then
  begin
    HighestNote := 127;
    LowestNote := 128 - VisibleNoteCount;
  end;
end;

end.

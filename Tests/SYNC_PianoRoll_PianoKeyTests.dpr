program SYNC_PianoRoll_PianoKeyTests;

// 白鍵・黒鍵判定と白鍵単位の音階方向位置を検証する。

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  SYNC_PianoRoll_PianoKeys in 'Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  BlackEnd, BlackStart, HighestNote, LowestNote: Integer;
  ReverseBlackEnd, ReverseBlackStart: Integer;
  ReverseWhiteEnd, ReverseWhiteStart, WhiteEnd, WhiteStart: Integer;
begin
  Check(not IsPianoBlackKey(60), 'C4 must be a white key');
  Check(IsPianoBlackKey(61), 'C sharp 4 must be a black key');
  Check(not IsPianoBlackKey(64), 'E4 must be a white key');
  Check(not IsPianoBlackKey(65), 'F4 must be a white key');
  Check(IsPianoBlackKey(70), 'A sharp 4 must be a black key');
  Check(not IsPianoBlackKey(71), 'B4 must be a white key');
  Check(SameValue(GetPianoKeyPitchCenter(61) -
    GetPianoKeyPitchCenter(60), 0.5), 'C to C sharp position mismatch');
  Check(SameValue(GetPianoKeyPitchCenter(62) -
    GetPianoKeyPitchCenter(60), 1.0), 'C to D position mismatch');
  Check(SameValue(GetPianoKeyPitchCenter(72) -
    GetPianoKeyPitchCenter(60), 7.0), 'octave position mismatch');
  GetPianoRollNoteAxisBounds(640, 60, 60, 72, 40.0, 0.8, False,
    WhiteStart, WhiteEnd);
  GetPianoRollNoteAxisBounds(640, 61, 60, 72, 40.0, 0.8, False,
    BlackStart, BlackEnd);
  Check((WhiteEnd - WhiteStart) = (BlackEnd - BlackStart),
    'white and black note widths must match');
  Check((WhiteEnd - WhiteStart) = 20,
    'note width must use the common narrow pitch band');
  Check((BlackStart + BlackEnd) - (WhiteStart + WhiteEnd) = 40,
    'vertical notes must align with their key centers');
  GetPianoRollNoteAxisBounds(240, 60, 60, 72, 20.0, 0.8, True,
    ReverseWhiteStart, ReverseWhiteEnd);
  GetPianoRollNoteAxisBounds(240, 61, 60, 72, 20.0, 0.8, True,
    ReverseBlackStart, ReverseBlackEnd);
  Check((ReverseWhiteEnd - ReverseWhiteStart) =
    (ReverseBlackEnd - ReverseBlackStart),
    'horizontal white and black note widths must match');
  Check((ReverseWhiteEnd - ReverseWhiteStart) = 10,
    'horizontal note width must use the common narrow pitch band');
  Check((ReverseBlackStart + ReverseBlackEnd) -
    (ReverseWhiteStart + ReverseWhiteEnd) = -20,
    'horizontal notes must align with their reversed key centers');
  ResolvePianoRollPitchRange(66, 13, LowestNote, HighestNote);
  Check((LowestNote = 60) and (HighestNote = 72),
    'odd centered pitch range mismatch');
  ResolvePianoRollPitchRange(64, 128, LowestNote, HighestNote);
  Check((LowestNote = 0) and (HighestNote = 127),
    'full pitch range mismatch');
  ResolvePianoRollPitchRange(2, 12, LowestNote, HighestNote);
  Check((LowestNote = 0) and (HighestNote = 11),
    'lower edge pitch range mismatch');
  ResolvePianoRollPitchRange(126, 12, LowestNote, HighestNote);
  Check((LowestNote = 116) and (HighestNote = 127),
    'upper edge pitch range mismatch');
  Writeln('PASS');
end.

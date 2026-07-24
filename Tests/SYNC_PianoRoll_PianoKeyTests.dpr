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
  Writeln('PASS');
end.

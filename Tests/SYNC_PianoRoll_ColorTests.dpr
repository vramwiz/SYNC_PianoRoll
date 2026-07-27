program SYNC_PianoRoll_ColorTests;

// 旧ピアノロールから移植した13配色と既存配色の共通色計算を検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  SYNC_PianoRoll_Colors in 'Source\Common\Color\SYNC_PianoRoll_Colors.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckColor(const Actual: TPianoRollColor; R, G, B, A: Integer;
  const MessageText: string);
begin
  Check((Actual.R = R) and (Actual.G = G) and (Actual.B = B) and
    (Actual.A = A), MessageText);
end;

function Resolve(TrackIndex, Key: Integer;
  Mode: TPianoRollTrackColorMode): TPianoRollColor;
var
  Palette: TPianoRollPalette;
begin
  SetDefaultPianoRollPalette(Palette);
  Result := ResolvePianoRollTrackColor(TrackIndex, Key, 10, 12, 48, 72,
    Mode, PianoRollColor(7, 8, 9, 211),
    PianoRollColor(255, 0, 0, 255),
    PianoRollColor(0, 0, 255, 255), Palette);
end;

var
  Color, OctaveColor: TPianoRollColor;
  Mode: TPianoRollTrackColorMode;
begin
  CheckColor(Resolve(10, 48, ptcmSingleColor), 7, 8, 9, 211,
    'single color mismatch');
  CheckColor(Resolve(11, 48, ptcmVariation1), 255, 145, 75, 255,
    'variation 1 mismatch');
  CheckColor(Resolve(10, 48, ptcmTrackDOS), 0, 0, 255, 255,
    'track DOS first color mismatch');
  CheckColor(Resolve(11, 48, ptcmTrackDOS), 0, 255, 0, 255,
    'track DOS second color mismatch');
  CheckColor(Resolve(10, 48, ptcmKeyDOS), 0, 0, 255, 255,
    'key DOS first color mismatch');
  CheckColor(Resolve(10, 49, ptcmKeyDOS), 0, 255, 0, 255,
    'key DOS second color mismatch');

  Check(Resolve(10, 48, ptcmTrackRainbow).R <>
    Resolve(12, 48, ptcmTrackRainbow).R,
    'track rainbow did not vary across tracks');
  Check(Resolve(10, 48, ptcmTrackSoft).B >
    Resolve(10, 48, ptcmTrackDark).B,
    'track soft and dark brightness mismatch');
  Check(Resolve(10, 48, ptcmKeyRainbow).R <>
    Resolve(10, 72, ptcmKeyRainbow).R,
    'key rainbow did not vary across keys');
  Check(Resolve(10, 48, ptcmKeySoft).B >
    Resolve(10, 48, ptcmKeyDark).B,
    'key soft and dark brightness mismatch');

  Color := Resolve(10, 48, ptcmDoReMiRainbow);
  OctaveColor := Resolve(10, 60, ptcmDoReMiRainbow);
  CheckColor(Color, OctaveColor.R, OctaveColor.G, OctaveColor.B, 255,
    'do-re-mi rainbow did not repeat by octave');
  Check(Resolve(10, 48, ptcmDoReMiSoft).R >
    Resolve(10, 48, ptcmDoReMiDark).R,
    'do-re-mi soft and dark brightness mismatch');

  CheckColor(Resolve(10, 48, ptcmGradientRGB), 0, 0, 255, 255,
    'RGB gradient low endpoint mismatch');
  CheckColor(Resolve(10, 72, ptcmGradientRGB), 255, 0, 0, 255,
    'RGB gradient high endpoint mismatch');
  Color := Resolve(10, 60, ptcmGradientHSV);
  // 旧HSV変換の300度境界も含めて同じ結果を維持する。
  Check((Color.R = 255) and (Color.G = 0) and (Color.B = 0),
    'HSV gradient midpoint mismatch');

  for Mode := Low(TPianoRollTrackColorMode) to
    High(TPianoRollTrackColorMode) do
  begin
    Color := Resolve(11, 60, Mode);
    Check(Color.A > 0, 'color mode returned a transparent color');
  end;
  Writeln('PASS');
end.

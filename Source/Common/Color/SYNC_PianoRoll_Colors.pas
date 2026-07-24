unit SYNC_PianoRoll_Colors;

// 表示タイプに依存しないRGBA色型とピアノロール共通パレットを定義する。

interface

type
  TPianoRollColor = record
    R, G, B, A: Byte;
  end;

  TPianoRollPalette = record
    WhiteKey: TPianoRollColor;
    KeyBorder: TPianoRollColor;
    BlackKey: TPianoRollColor;
    WhiteLane: TPianoRollColor;
    BlackLane: TPianoRollColor;
    BeatLine: TPianoRollColor;
    MeasureLine: TPianoRollColor;
    StrikeLine: TPianoRollColor;
    TrackColors: array[0..5] of TPianoRollColor;
  end;

function PianoRollColor(R, G, B, A: Byte): TPianoRollColor;
procedure SetDefaultPianoRollPalette(out Palette: TPianoRollPalette);

implementation

function PianoRollColor(R, G, B, A: Byte): TPianoRollColor;
begin
  Result.R := R;
  Result.G := G;
  Result.B := B;
  Result.A := A;
end;

procedure SetDefaultPianoRollPalette(out Palette: TPianoRollPalette);
begin
  Palette.WhiteKey := PianoRollColor(242, 242, 242, 255);
  Palette.KeyBorder := PianoRollColor(72, 72, 72, 255);
  Palette.BlackKey := PianoRollColor(24, 24, 24, 255);
  Palette.WhiteLane := PianoRollColor(238, 238, 242, 28);
  Palette.BlackLane := PianoRollColor(110, 110, 120, 24);
  Palette.BeatLine := PianoRollColor(255, 255, 255, 48);
  Palette.MeasureLine := PianoRollColor(255, 190, 80, 120);
  Palette.StrikeLine := PianoRollColor(255, 255, 255, 160);
  Palette.TrackColors[0] := PianoRollColor(80, 210, 255, 255);
  Palette.TrackColors[1] := PianoRollColor(255, 120, 180, 255);
  Palette.TrackColors[2] := PianoRollColor(120, 235, 140, 255);
  Palette.TrackColors[3] := PianoRollColor(255, 205, 80, 255);
  Palette.TrackColors[4] := PianoRollColor(175, 130, 255, 255);
  Palette.TrackColors[5] := PianoRollColor(255, 145, 75, 255);
end;

end.

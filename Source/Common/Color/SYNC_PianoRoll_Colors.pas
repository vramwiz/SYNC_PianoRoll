unit SYNC_PianoRoll_Colors;

// 表示タイプに依存しないRGBA色型とピアノロール共通パレットを定義する。

interface

type
  TPianoRollColor = record
    R, G, B, A: Byte;
  end;

  // 表示方向に依存せず、ノートへ適用する配色規則を選ぶ。
  TPianoRollTrackColorMode = (
    ptcmSingleColor,
    ptcmVariation1
  );

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
function DarkenPianoRollColor(const Color: TPianoRollColor;
  Amount: Double): TPianoRollColor;
function LightenPianoRollColor(const Color: TPianoRollColor;
  Amount: Double): TPianoRollColor;
function ResolvePianoRollTrackColor(TrackIndex: Integer;
  ColorMode: TPianoRollTrackColorMode; const SingleColor: TPianoRollColor;
  const Palette: TPianoRollPalette): TPianoRollColor;
procedure SetDefaultPianoRollPalette(out Palette: TPianoRollPalette);

implementation

uses
  System.Math;

function PianoRollColor(R, G, B, A: Byte): TPianoRollColor;
begin
  Result.R := R;
  Result.G := G;
  Result.B := B;
  Result.A := A;
end;

function DarkenPianoRollColor(const Color: TPianoRollColor;
  Amount: Double): TPianoRollColor;
begin
  Amount := EnsureRange(Amount, 0.0, 1.0);
  Result := PianoRollColor(
    Round(Color.R * (1.0 - Amount)),
    Round(Color.G * (1.0 - Amount)),
    Round(Color.B * (1.0 - Amount)),
    Color.A);
end;

function LightenPianoRollColor(const Color: TPianoRollColor;
  Amount: Double): TPianoRollColor;
begin
  Amount := EnsureRange(Amount, 0.0, 1.0);
  Result := PianoRollColor(
    Round(Color.R + (255 - Color.R) * Amount),
    Round(Color.G + (255 - Color.G) * Amount),
    Round(Color.B + (255 - Color.B) * Amount),
    Color.A);
end;

function ResolvePianoRollTrackColor(TrackIndex: Integer;
  ColorMode: TPianoRollTrackColorMode; const SingleColor: TPianoRollColor;
  const Palette: TPianoRollPalette): TPianoRollColor;
var
  ColorIndex: Integer;
begin
  case ColorMode of
    ptcmVariation1:
      begin
        // バリエーション1は負の番号も同じ6色へ安定して循環させる。
        ColorIndex := TrackIndex mod Length(Palette.TrackColors);
        if ColorIndex < 0 then
          Inc(ColorIndex, Length(Palette.TrackColors));
        Result := Palette.TrackColors[ColorIndex];
      end;
  else
    // 未知の方式も既定の単色として扱い、将来の列挙追加に備える。
    Result := SingleColor;
  end;
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

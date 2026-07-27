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
    ptcmVariation1,
    ptcmTrackDOS,
    ptcmTrackRainbow,
    ptcmTrackSoft,
    ptcmTrackDark,
    ptcmKeyDOS,
    ptcmKeyRainbow,
    ptcmKeySoft,
    ptcmKeyDark,
    ptcmDoReMiRainbow,
    ptcmDoReMiSoft,
    ptcmDoReMiDark,
    ptcmGradientRGB,
    ptcmGradientHSV
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
function ResolvePianoRollTrackColor(TrackIndex, Key, MinTrack, MaxTrack,
  MinKey, MaxKey: Integer;
  ColorMode: TPianoRollTrackColorMode; const SingleColor: TPianoRollColor;
  const GradientColor1, GradientColor2: TPianoRollColor;
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

procedure HSVToPianoRollRGB(H, S, V: Double; out R, G, B: Byte);
var
  C, M, Rp, Gp, Bp, X: Double;
begin
  while H >= 360.0 do
    H := H - 360.0;
  while H < 0.0 do
    H := H + 360.0;
  C := V * S;
  X := C * (1.0 - Abs(Frac(H / 60.0) * 2.0 - 1.0));
  M := V - C;
  if H < 60.0 then
  begin
    Rp := C; Gp := X; Bp := 0.0;
  end
  else if H < 120.0 then
  begin
    Rp := X; Gp := C; Bp := 0.0;
  end
  else if H < 180.0 then
  begin
    Rp := 0.0; Gp := C; Bp := X;
  end
  else if H < 240.0 then
  begin
    Rp := 0.0; Gp := X; Bp := C;
  end
  else if H < 300.0 then
  begin
    Rp := X; Gp := 0.0; Bp := C;
  end
  else
  begin
    Rp := C; Gp := 0.0; Bp := X;
  end;
  R := Round((Rp + M) * 255.0);
  G := Round((Gp + M) * 255.0);
  B := Round((Bp + M) * 255.0);
end;

procedure PianoRollRGBToHSV(const Color: TPianoRollColor;
  out H, S, V: Double);
var
  B, CMax, CMin, Delta, G, R: Double;
begin
  R := Color.R / 255.0;
  G := Color.G / 255.0;
  B := Color.B / 255.0;
  CMax := Max(R, Max(G, B));
  CMin := Min(R, Min(G, B));
  Delta := CMax - CMin;
  if Delta = 0.0 then
    H := 0.0
  else if CMax = R then
    H := 60.0 * ((G - B) / Delta)
  else if CMax = G then
    H := 60.0 * (((B - R) / Delta) + 2.0)
  else
    H := 60.0 * (((R - G) / Delta) + 4.0);
  while H < 0.0 do
    H := H + 360.0;
  while H >= 360.0 do
    H := H - 360.0;
  if CMax = 0.0 then
    S := 0.0
  else
    S := Delta / CMax;
  V := CMax;
end;

function NormalizeColorIndex(Value, Minimum, Maximum: Integer;
  out T: Double): Integer;
begin
  Result := Value - Minimum;
  if Maximum > Minimum then
    T := (Value - Minimum) / (Maximum - Minimum)
  else
    T := 0.0;
end;

function DOSPianoRollColor(Index: Integer): TPianoRollColor;
const
  Table: array[0..11, 0..2] of Byte = (
    (0, 0, 255), (0, 255, 0), (0, 255, 255),
    (255, 0, 0), (255, 0, 255), (255, 255, 0),
    (0, 0, 128), (0, 128, 0), (0, 128, 128),
    (128, 0, 0), (128, 0, 128), (128, 128, 0)
  );
begin
  Index := Index mod Length(Table);
  if Index < 0 then
    Inc(Index, Length(Table));
  Result := PianoRollColor(Table[Index, 0], Table[Index, 1],
    Table[Index, 2], 255);
end;

function RainbowRangeColor(T: Double): TPianoRollColor;
var
  Hue: Double;
begin
  Hue := 300.0 * (1.0 - T);
  Result := PianoRollColor(
    Round(127.0 * (1.0 + Cos((Hue - 0.0) * Pi / 180.0))),
    Round(127.0 * (1.0 + Cos((Hue - 120.0) * Pi / 180.0))),
    Round(127.0 * (1.0 + Cos((Hue - 240.0) * Pi / 180.0))),
    255);
end;

function HSVPianoRollColor(H, S, V: Double): TPianoRollColor;
var
  B, G, R: Byte;
begin
  HSVToPianoRollRGB(H, S, V, R, G, B);
  Result := PianoRollColor(R, G, B, 255);
end;

function DoReMiPianoRollColor(Key: Integer;
  ColorMode: TPianoRollTrackColorMode): TPianoRollColor;
const
  Hues: array[0..11] of Double = (
    0.0, 15.0, 30.0, 45.0, 60.0, 120.0,
    180.0, 240.0, 255.0, 270.0, 285.0, 300.0
  );
  HalfTones: array[0..11] of Boolean = (
    False, True, False, True, False, False,
    True, False, True, False, True, False
  );
var
  Index: Integer;
  Scale: Double;
begin
  Index := Key mod 12;
  if Index < 0 then
    Inc(Index, 12);
  case ColorMode of
    ptcmDoReMiSoft:
      if HalfTones[Index] then
      begin
        Result := HSVPianoRollColor(Hues[Index], 0.78, 0.82);
        Scale := 0.78;
        Result.R := Round(Result.R * Scale);
        Result.G := Round(Result.G * Scale);
        Result.B := Round(Result.B * Scale);
      end
      else
      begin
        Result := HSVPianoRollColor(Hues[Index], 0.72, 1.0);
        if Hues[Index] >= 180.0 then
          Result := LightenPianoRollColor(Result, 0.28)
        else
          Result := LightenPianoRollColor(Result, 0.12);
      end;
    ptcmDoReMiDark:
      if HalfTones[Index] then
      begin
        Result := HSVPianoRollColor(Hues[Index], 0.70, 0.42);
        Result.R := Round(Result.R * 0.90);
        Result.G := Round(Result.G * 0.90);
        Result.B := Round(Result.B * 0.90);
      end
      else
      begin
        Result := HSVPianoRollColor(Hues[Index], 0.78, 0.58);
        if Hues[Index] >= 180.0 then
          Result := LightenPianoRollColor(Result, 0.06);
      end;
  else
    if HalfTones[Index] then
    begin
      Result := HSVPianoRollColor(Hues[Index], 0.92, 0.62);
      Result.R := Round(Result.R * 0.72);
      Result.G := Round(Result.G * 0.72);
      Result.B := Round(Result.B * 0.72);
    end
    else
    begin
      Result := HSVPianoRollColor(Hues[Index], 0.95, 1.0);
      if Hues[Index] >= 180.0 then
        Result := LightenPianoRollColor(Result, 0.08);
    end;
  end;
end;

function GradientPianoRollColor(Key, MinKey, MaxKey: Integer;
  ColorMode: TPianoRollTrackColorMode;
  const Color1, Color2: TPianoRollColor): TPianoRollColor;
var
  H, H1, H2, HueDelta, S, S1, S2, T, V, V1, V2: Double;
  B, G, R: Byte;
begin
  if MinKey = MaxKey then
    Exit(Color1);
  NormalizeColorIndex(Key, MinKey, MaxKey, T);
  if ColorMode = ptcmGradientRGB then
    Exit(PianoRollColor(
      Round(Color2.R + (Color1.R - Color2.R) * T),
      Round(Color2.G + (Color1.G - Color2.G) * T),
      Round(Color2.B + (Color1.B - Color2.B) * T),
      Round(Color2.A + (Color1.A - Color2.A) * T)));

  PianoRollRGBToHSV(Color1, H1, S1, V1);
  PianoRollRGBToHSV(Color2, H2, S2, V2);
  HueDelta := H1 - H2;
  if HueDelta > 180.0 then
    HueDelta := HueDelta - 360.0
  else if HueDelta < -180.0 then
    HueDelta := HueDelta + 360.0;
  H := H2 + HueDelta * T;
  S := S2 + (S1 - S2) * T;
  V := V2 + (V1 - V2) * T;
  HSVToPianoRollRGB(H, S, V, R, G, B);
  Result := PianoRollColor(R, G, B,
    Round(Color2.A + (Color1.A - Color2.A) * T));
end;

function ResolvePianoRollTrackColor(TrackIndex, Key, MinTrack, MaxTrack,
  MinKey, MaxKey: Integer;
  ColorMode: TPianoRollTrackColorMode; const SingleColor: TPianoRollColor;
  const GradientColor1, GradientColor2: TPianoRollColor;
  const Palette: TPianoRollPalette): TPianoRollColor;
var
  ColorIndex: Integer;
  T: Double;
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
    ptcmTrackDOS:
      Result := DOSPianoRollColor(
        NormalizeColorIndex(TrackIndex, MinTrack, MaxTrack, T));
    ptcmTrackRainbow:
      begin
        NormalizeColorIndex(TrackIndex, MinTrack, MaxTrack, T);
        Result := RainbowRangeColor(T);
      end;
    ptcmTrackSoft:
      begin
        NormalizeColorIndex(TrackIndex, MinTrack, MaxTrack, T);
        if MinTrack = MaxTrack then
          Result := HSVPianoRollColor(210.0, 0.35, 1.0)
        else
          Result := HSVPianoRollColor(220.0 - 160.0 * T, 0.35, 1.0);
      end;
    ptcmTrackDark:
      begin
        NormalizeColorIndex(TrackIndex, MinTrack, MaxTrack, T);
        if MinTrack = MaxTrack then
          Result := HSVPianoRollColor(210.0, 0.65, 0.45)
        else
          Result := HSVPianoRollColor(260.0 - 200.0 * T, 0.65, 0.45);
      end;
    ptcmKeyDOS:
      Result := DOSPianoRollColor(
        NormalizeColorIndex(Key, MinKey, MaxKey, T));
    ptcmKeyRainbow:
      begin
        NormalizeColorIndex(Key, MinKey, MaxKey, T);
        Result := RainbowRangeColor(T);
      end;
    ptcmKeySoft:
      begin
        NormalizeColorIndex(Key, MinKey, MaxKey, T);
        if MinKey = MaxKey then
          Result := HSVPianoRollColor(200.0, 0.30, 1.0)
        else
          Result := HSVPianoRollColor(210.0 - 170.0 * T, 0.30, 1.0);
      end;
    ptcmKeyDark:
      begin
        NormalizeColorIndex(Key, MinKey, MaxKey, T);
        if MinKey = MaxKey then
          Result := HSVPianoRollColor(215.0, 0.70, 0.40)
        else
          Result := HSVPianoRollColor(240.0 - 210.0 * T, 0.70, 0.40);
      end;
    ptcmDoReMiRainbow, ptcmDoReMiSoft, ptcmDoReMiDark:
      Result := DoReMiPianoRollColor(Key, ColorMode);
    ptcmGradientRGB, ptcmGradientHSV:
      Result := GradientPianoRollColor(Key, MinKey, MaxKey, ColorMode,
        GradientColor1, GradientColor2);
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

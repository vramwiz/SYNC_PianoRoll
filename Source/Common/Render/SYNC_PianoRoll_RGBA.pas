unit SYNC_PianoRoll_RGBA;

// 表示タイプに依存しない透明RGBAキャンバスと基本図形描画を提供する。

interface

uses
  AviUtl2FilterTypes,
  SYNC_PianoRoll_Colors;

type
  TPianoRollCanvas = record
  private
    FBuffer: PPIXEL_RGBA;
    FWidth: Integer;
    FHeight: Integer;
  public
    procedure Initialize(Buffer: PPIXEL_RGBA; Width, Height: Integer);
    procedure Clear;
    procedure BlendRadialGlow(CenterX, CenterY, RadiusX, RadiusY,
      PeakAlpha: Integer; const Color: TPianoRollColor);
    procedure BlendRectangle(LeftPosition, TopPosition, RightPosition,
      BottomPosition: Integer; const Color: TPianoRollColor);
    procedure FillRectangle(LeftPosition, TopPosition, RightPosition,
      BottomPosition: Integer; const Color: TPianoRollColor);
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

implementation

uses
  System.Math;

type
  TPixelArray = array[0..(MaxInt div SizeOf(TPIXEL_RGBA)) - 1] of TPIXEL_RGBA;
  PPixelArray = ^TPixelArray;

procedure BlendPixel(var Destination: TPIXEL_RGBA;
  const Source: TPianoRollColor);
var
  DestinationFactor, OutputAlpha: Integer;
begin
  if Source.A = 0 then
    Exit;
  if (Source.A = 255) or (Destination.A = 0) then
  begin
    Destination.R := Source.R;
    Destination.G := Source.G;
    Destination.B := Source.B;
    Destination.A := Source.A;
    Exit;
  end;

  // 非乗算済みRGBAをsource-over合成し、透明背景上でも色を濁らせない。
  DestinationFactor := Destination.A * (255 - Source.A);
  OutputAlpha := Source.A * 255 + DestinationFactor;
  Destination.R := (Source.R * Source.A * 255 +
    Destination.R * DestinationFactor) div OutputAlpha;
  Destination.G := (Source.G * Source.A * 255 +
    Destination.G * DestinationFactor) div OutputAlpha;
  Destination.B := (Source.B * Source.A * 255 +
    Destination.B * DestinationFactor) div OutputAlpha;
  Destination.A := OutputAlpha div 255;
end;

procedure TPianoRollCanvas.BlendRadialGlow(CenterX, CenterY, RadiusX,
  RadiusY, PeakAlpha: Integer; const Color: TPianoRollColor);
var
  CoreStrength, Distance, Falloff, NormalizedX, NormalizedY: Double;
  GlowColor: TPianoRollColor;
  X, XEnd, XStart, Y, YEnd, YStart: Integer;
begin
  if (FBuffer = nil) or (FWidth <= 0) or (FHeight <= 0) or
    (RadiusX <= 0) or (RadiusY <= 0) or (PeakAlpha <= 0) then
    Exit;
  PeakAlpha := EnsureRange(PeakAlpha, 0, 255);
  XStart := Max(0, CenterX - RadiusX);
  XEnd := Min(FWidth - 1, CenterX + RadiusX);
  YStart := Max(0, CenterY - RadiusY);
  YEnd := Min(FHeight - 1, CenterY + RadiusY);
  for Y := YStart to YEnd do
    for X := XStart to XEnd do
    begin
      NormalizedX := (X - CenterX) / RadiusX;
      NormalizedY := (Y - CenterY) / RadiusY;
      Distance := Sqrt(NormalizedX * NormalizedX +
        NormalizedY * NormalizedY);
      if Distance > 1.0 then
        Continue;

      // smoothstep減衰で広い中間光を残しつつ、外周だけを滑らかに透明へつなぐ。
      Falloff := 1.0 - Distance;
      Falloff := Falloff * Falloff * (3.0 - 2.0 * Falloff);
      CoreStrength := Sqr(Falloff);
      GlowColor.R := Round(Color.R + (255 - Color.R) * CoreStrength);
      GlowColor.G := Round(Color.G + (255 - Color.G) * CoreStrength);
      GlowColor.B := Round(Color.B + (255 - Color.B) * CoreStrength);
      GlowColor.A := Round(PeakAlpha * Falloff);
      BlendPixel(PPixelArray(FBuffer)^[Y * FWidth + X], GlowColor);
    end;
end;

procedure TPianoRollCanvas.BlendRectangle(LeftPosition, TopPosition,
  RightPosition, BottomPosition: Integer; const Color: TPianoRollColor);
var
  X, Y: Integer;
begin
  if (FBuffer = nil) or (FWidth <= 0) or (FHeight <= 0) or
    (Color.A = 0) then
    Exit;
  LeftPosition := EnsureRange(LeftPosition, 0, FWidth);
  RightPosition := EnsureRange(RightPosition, 0, FWidth);
  TopPosition := EnsureRange(TopPosition, 0, FHeight);
  BottomPosition := EnsureRange(BottomPosition, 0, FHeight);
  if (LeftPosition >= RightPosition) or (TopPosition >= BottomPosition) then
    Exit;
  for Y := TopPosition to BottomPosition - 1 do
    for X := LeftPosition to RightPosition - 1 do
      BlendPixel(PPixelArray(FBuffer)^[Y * FWidth + X], Color);
end;

procedure TPianoRollCanvas.Initialize(Buffer: PPIXEL_RGBA;
  Width, Height: Integer);
begin
  FBuffer := Buffer;
  FWidth := Width;
  FHeight := Height;
end;

procedure TPianoRollCanvas.Clear;
begin
  if (FBuffer <> nil) and (FWidth > 0) and (FHeight > 0) then
    FillChar(FBuffer^, NativeInt(FWidth) * FHeight * SizeOf(TPIXEL_RGBA), 0);
end;

procedure TPianoRollCanvas.FillRectangle(LeftPosition, TopPosition,
  RightPosition, BottomPosition: Integer; const Color: TPianoRollColor);
var
  Pixel: TPIXEL_RGBA;
  PitchPosition, TimePosition: Integer;
begin
  if (FBuffer = nil) or (FWidth <= 0) or (FHeight <= 0) then
    Exit;
  LeftPosition := EnsureRange(LeftPosition, 0, FWidth);
  RightPosition := EnsureRange(RightPosition, 0, FWidth);
  TopPosition := EnsureRange(TopPosition, 0, FHeight);
  BottomPosition := EnsureRange(BottomPosition, 0, FHeight);
  if (LeftPosition >= RightPosition) or (TopPosition >= BottomPosition) then
    Exit;

  Pixel.R := Color.R;
  Pixel.G := Color.G;
  Pixel.B := Color.B;
  Pixel.A := Color.A;
  for TimePosition := TopPosition to BottomPosition - 1 do
    for PitchPosition := LeftPosition to RightPosition - 1 do
      PPixelArray(FBuffer)^[TimePosition * FWidth + PitchPosition] := Pixel;
end;

end.

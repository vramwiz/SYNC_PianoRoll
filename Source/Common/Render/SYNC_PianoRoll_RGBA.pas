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

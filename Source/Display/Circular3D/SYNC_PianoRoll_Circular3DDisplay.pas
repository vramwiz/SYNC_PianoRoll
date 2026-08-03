unit SYNC_PianoRoll_Circular3DDisplay;

// 音階を円周、時間をZ軸へ割り当てる3D Type2／Type3の円環鍵盤とノートを生成する。

interface

uses
  AviUtl2FilterTypes,
  SYNC_PianoRoll_DisplayTypes,
  SYNC_PianoRoll_MusicData;

function DrawCircularPianoRoll3D(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings; Horizontal,
  Outward: Boolean): Boolean;
function ResolveCircularPianoRollRadius(Width, Height: Integer;
  const Settings: TPianoRollDisplaySettings;
  ReserveOuterMargin: Boolean): Double;

implementation

uses
  System.Math,
  SYNC_PianoRoll_Colors,
  SYNC_PianoRoll_PianoKeys,
  SYNC_PianoRoll_PitchFollow;

const
  CIRCLE_SEGMENT_COUNT = 192;
  GLOW_GRID_HALF = 6;
  MAX_QUAD_COUNT = 65536;
  STRIKE_GLOW_DURATION = 0.35;

type
  TVertexColorArray = array of TVERTEX_COLOR;

procedure SetVertex(var Vertex: TVERTEX_COLOR; X, Y, Z: Single;
  const Color: TPianoRollColor);
begin
  Vertex.X := X;
  Vertex.Y := Y;
  Vertex.Z := Z;
  Vertex.R := Color.R / 255.0;
  Vertex.G := Color.G / 255.0;
  Vertex.B := Color.B / 255.0;
  Vertex.A := Color.A / 255.0;
end;

function ShadeColor(const Color: TPianoRollColor;
  Brightness: Double): TPianoRollColor;
begin
  Brightness := EnsureRange(Brightness, 0.0, 1.0);
  Result := PianoRollColor(Round(Color.R * Brightness),
    Round(Color.G * Brightness), Round(Color.B * Brightness), Color.A);
end;

function MakeGlowColor(const Color: TPianoRollColor;
  WhiteAmount: Double; Alpha: Integer): TPianoRollColor;
begin
  WhiteAmount := EnsureRange(WhiteAmount, 0.0, 1.0);
  Result := PianoRollColor(
    Round(Color.R + (255 - Color.R) * WhiteAmount),
    Round(Color.G + (255 - Color.G) * WhiteAmount),
    Round(Color.B + (255 - Color.B) * WhiteAmount),
    EnsureRange(Alpha, 0, 255));
end;

function GetGlowVertexColor(const Color: TPianoRollColor;
  NormalizedRadius, NormalizedAngle: Double;
  PeakAlpha: Integer): TPianoRollColor;
var
  Distance, Strength: Double;
begin
  Distance := Sqrt(Sqr(NormalizedRadius) + Sqr(NormalizedAngle));
  if Distance >= 1.0 then
    Strength := 0.0
  else
    Strength := 1.0 - Distance * Distance * (3.0 - 2.0 * Distance);
  Result := MakeGlowColor(Color, 0.25 + Strength * 0.65,
    Round(PeakAlpha * Strength));
end;

procedure EnsureVertexCapacity(var Vertices: TVertexColorArray;
  RequiredCount: Integer);
begin
  if RequiredCount > Length(Vertices) then
    SetLength(Vertices, Min(MAX_QUAD_COUNT * 4,
      Max(1024, Length(Vertices) * 2)));
end;

function ResolveCircularPianoRollRadius(Width, Height: Integer;
  const Settings: TPianoRollDisplaySettings;
  ReserveOuterMargin: Boolean): Double;
var
  AutoRadius, HalfKeyLength, MaximumFittingRadius, OuterEffectMargin,
    ShortSide: Double;
begin
  if Settings.Radius > 0.0 then
    Exit(Settings.Radius);

  ShortSide := Max(1.0, Min(Width, Height));
  HalfKeyLength := Max(0.0, Settings.KeyLength) * 0.5;
  OuterEffectMargin := Abs(Settings.NotePositionOffset);
  if ReserveOuterMargin then
    // 外向き円環または円筒の厚みと打鍵グローまで短辺の48%以内へ収める。
    OuterEffectMargin := Max(OuterEffectMargin, Max(
      Max(Max(0.0, Settings.Note3DThickness),
        Max(10.0, Max(0.0, Settings.KeyLength) * 0.13)),
      Max(4.0, Max(0.0, Settings.WhiteKey3DThickness)) +
        Max(2.0, Max(0.0, Settings.BlackKey3DThickness))));
  MaximumFittingRadius := Max(1.0,
    ShortSide * 0.48 - HalfKeyLength - OuterEffectMargin);
  AutoRadius := Max(HalfKeyLength + 4.0, ShortSide * 0.30);
  Result := Max(HalfKeyLength + 1.0,
    Min(AutoRadius, MaximumFittingRadius));
end;

function GetNoteEndSeconds(const Note: TPianoRollNoteData): Double;
begin
  Result := Note.EndSeconds;
  if Result < Note.StartSeconds then
    Result := Note.StartSeconds + 0.2;
end;

function IsNoteActiveAtTime(const Note: TPianoRollNoteData;
  TimeSeconds: Double): Boolean;
begin
  Result := (TimeSeconds >= Note.StartSeconds) and
    (TimeSeconds < GetNoteEndSeconds(Note));
end;

function PitchToAngle(Pitch, CenterPitch, PitchSpan: Double;
  Horizontal: Boolean): Double;
var
  ReferenceAngle, Winding: Double;
begin
  if Horizontal then
  begin
    ReferenceAngle := Pi;
    Winding := -1.0;
  end
  else
  begin
    ReferenceAngle := Pi * 0.5;
    Winding := 1.0;
  end;
  Result := ReferenceAngle +
    Winding * 2.0 * Pi * (Pitch - CenterPitch) / PitchSpan;
end;

procedure AppendAnnularSector(var Vertices: TVertexColorArray;
  var VertexCount: Integer; InnerRadius, OuterRadius, Angle0, Angle1,
  Z: Double; const Color: TPianoRollColor);
var
  A0, A1, AngleStep: Double;
  I, SegmentCount: Integer;
begin
  if (OuterRadius <= InnerRadius) or (Angle1 = Angle0) then
    Exit;
  SegmentCount := Max(1, Ceil(Abs(Angle1 - Angle0) /
    (2.0 * Pi / CIRCLE_SEGMENT_COUNT)));
  AngleStep := (Angle1 - Angle0) / SegmentCount;
  for I := 0 to SegmentCount - 1 do
  begin
    if VertexCount div 4 >= MAX_QUAD_COUNT then
      Exit;
    EnsureVertexCapacity(Vertices, VertexCount + 4);
    A0 := Angle0 + AngleStep * I;
    A1 := A0 + AngleStep;
    SetVertex(Vertices[VertexCount],
      Cos(A0) * InnerRadius, Sin(A0) * InnerRadius, Z, Color);
    SetVertex(Vertices[VertexCount + 1],
      Cos(A0) * OuterRadius, Sin(A0) * OuterRadius, Z, Color);
    SetVertex(Vertices[VertexCount + 2],
      Cos(A1) * OuterRadius, Sin(A1) * OuterRadius, Z, Color);
    SetVertex(Vertices[VertexCount + 3],
      Cos(A1) * InnerRadius, Sin(A1) * InnerRadius, Z, Color);
    Inc(VertexCount, 4);
  end;
end;

procedure AppendCylindricalRibbon(var Vertices: TVertexColorArray;
  var VertexCount: Integer; Radius, Angle0, Angle1, Z0, Z1: Double;
  const Color: TPianoRollColor);
var
  A0, A1, AngleStep: Double;
  I, SegmentCount: Integer;
begin
  if (Radius <= 0.0) or (Angle1 = Angle0) or (Z1 <= Z0) then
    Exit;
  SegmentCount := Max(1, Ceil(Abs(Angle1 - Angle0) /
    (2.0 * Pi / CIRCLE_SEGMENT_COUNT)));
  AngleStep := (Angle1 - Angle0) / SegmentCount;
  for I := 0 to SegmentCount - 1 do
  begin
    if VertexCount div 4 >= MAX_QUAD_COUNT then
      Exit;
    EnsureVertexCapacity(Vertices, VertexCount + 4);
    A0 := Angle0 + AngleStep * I;
    A1 := A0 + AngleStep;
    SetVertex(Vertices[VertexCount],
      Cos(A0) * Radius, Sin(A0) * Radius, Z0, Color);
    SetVertex(Vertices[VertexCount + 1],
      Cos(A0) * Radius, Sin(A0) * Radius, Z1, Color);
    SetVertex(Vertices[VertexCount + 2],
      Cos(A1) * Radius, Sin(A1) * Radius, Z1, Color);
    SetVertex(Vertices[VertexCount + 3],
      Cos(A1) * Radius, Sin(A1) * Radius, Z0, Color);
    Inc(VertexCount, 4);
  end;
end;

procedure AppendRadialSide(var Vertices: TVertexColorArray;
  var VertexCount: Integer; Radius0, Radius1, Angle, Z0, Z1: Double;
  const Color: TPianoRollColor);
begin
  if (VertexCount div 4 >= MAX_QUAD_COUNT) or
    (Radius0 = Radius1) or (Z0 = Z1) then
    Exit;
  EnsureVertexCapacity(Vertices, VertexCount + 4);
  SetVertex(Vertices[VertexCount],
    Cos(Angle) * Radius0, Sin(Angle) * Radius0, Z0, Color);
  SetVertex(Vertices[VertexCount + 1],
    Cos(Angle) * Radius1, Sin(Angle) * Radius1, Z0, Color);
  SetVertex(Vertices[VertexCount + 2],
    Cos(Angle) * Radius1, Sin(Angle) * Radius1, Z1, Color);
  SetVertex(Vertices[VertexCount + 3],
    Cos(Angle) * Radius0, Sin(Angle) * Radius0, Z1, Color);
  Inc(VertexCount, 4);
end;

procedure AppendExtrudedCylindricalRibbon(var Vertices: TVertexColorArray;
  var VertexCount: Integer; SurfaceRadius, Angle0, Angle1, Z0, Z1,
  Thickness: Double; GrowOutward: Boolean; const Color: TPianoRollColor);
var
  InnerRadius, OuterRadius: Double;
  EndShade, SideShade: TPianoRollColor;
begin
  Thickness := Max(0.0, Thickness);
  if Thickness <= 0.0 then
  begin
    // 厚み0でも表示側へ法線を向け、外向き平面ノートを背面扱いにしない。
    if GrowOutward then
      AppendCylindricalRibbon(Vertices, VertexCount, SurfaceRadius,
        Angle1, Angle0, Z0, Z1, Color)
    else
      AppendCylindricalRibbon(Vertices, VertexCount, SurfaceRadius,
        Angle0, Angle1, Z0, Z1, Color);
    Exit;
  end;

  if GrowOutward then
  begin
    InnerRadius := SurfaceRadius;
    OuterRadius := SurfaceRadius + Thickness;
  end
  else
  begin
    InnerRadius := Max(1.0, SurfaceRadius - Thickness);
    OuterRadius := SurfaceRadius;
  end;
  if InnerRadius >= OuterRadius then
    Exit;
  SideShade := ShadeColor(Color, 0.62);
  EndShade := ShadeColor(Color, 0.48);

  // 厚みの背面と4つの端面を先に閉じ、表示側の主面を最後に重ねる。
  if GrowOutward then
    AppendCylindricalRibbon(Vertices, VertexCount, InnerRadius,
      Angle0, Angle1, Z0, Z1, SideShade)
  else
    AppendCylindricalRibbon(Vertices, VertexCount, OuterRadius,
      Angle1, Angle0, Z0, Z1, SideShade);
  AppendRadialSide(Vertices, VertexCount, InnerRadius, OuterRadius,
    Angle0, Z0, Z1, SideShade);
  AppendRadialSide(Vertices, VertexCount, OuterRadius, InnerRadius,
    Angle1, Z0, Z1, SideShade);
  AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
    Angle1, Angle0, Z0, EndShade);
  AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
    Angle0, Angle1, Z1, EndShade);
  if GrowOutward then
    AppendCylindricalRibbon(Vertices, VertexCount, OuterRadius,
      Angle1, Angle0, Z0, Z1, Color)
  else
    AppendCylindricalRibbon(Vertices, VertexCount, InnerRadius,
      Angle0, Angle1, Z0, Z1, Color);
end;

procedure AppendConnectedKeyboardBand(var Vertices: TVertexColorArray;
  var VertexCount: Integer; InnerRadius, OuterRadius, FrontZ, BackZ: Double;
  const Color: TPianoRollColor);
begin
  if (OuterRadius <= InnerRadius) or (BackZ <= FrontZ) then
    Exit;

  // 鍵盤の音階方向両端を閉じた形に相当する、継ぎ目のない側面を作る。
  AppendCylindricalRibbon(Vertices, VertexCount, InnerRadius, 0.0,
    2.0 * Pi, FrontZ, BackZ, ShadeColor(Color, 0.55));
  AppendCylindricalRibbon(Vertices, VertexCount, OuterRadius, 2.0 * Pi,
    0.0, FrontZ, BackZ, ShadeColor(Color, 0.70));
  // 斜め後方から見ても帯の開口部が露出しないよう、背面も閉じる。
  AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
    2.0 * Pi, 0.0, BackZ, ShadeColor(Color, 0.42));
end;

procedure AppendExtrudedAnnularKey(var Vertices: TVertexColorArray;
  var VertexCount: Integer; InnerRadius, OuterRadius, Angle0, Angle1,
  BaseZ, FrontZ: Double; const Color: TPianoRollColor);
var
  EndColor, SideColor: TPianoRollColor;
begin
  if (OuterRadius <= InnerRadius) or (Angle1 = Angle0) then
    Exit;
  if FrontZ >= BaseZ then
  begin
    AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
      Angle0, Angle1, FrontZ, Color);
    Exit;
  end;

  SideColor := ShadeColor(Color, 0.62);
  EndColor := ShadeColor(Color, 0.48);
  AppendCylindricalRibbon(Vertices, VertexCount, InnerRadius, Angle0,
    Angle1, FrontZ, BaseZ, SideColor);
  AppendCylindricalRibbon(Vertices, VertexCount, OuterRadius, Angle1,
    Angle0, FrontZ, BaseZ, SideColor);
  AppendRadialSide(Vertices, VertexCount, InnerRadius, OuterRadius,
    Angle0, FrontZ, BaseZ, EndColor);
  AppendRadialSide(Vertices, VertexCount, OuterRadius, InnerRadius,
    Angle1, FrontZ, BaseZ, EndColor);
  AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
    Angle0, Angle1, FrontZ, Color);
end;

procedure AppendActiveCircularKeys(var Vertices: TVertexColorArray;
  var VertexCount: Integer; const Data: IPianoRollMusicData;
  TimeSeconds, Radius, InnerRadius, OuterRadius, CenterPitch,
  PitchSpan, WhiteFrontZ, BlackFrontZ: Double;
  LowestKey, HighestKey, MinTrack, MaxTrack, MinMusicKey,
  MaxMusicKey: Integer; const Settings: TPianoRollDisplaySettings;
  Horizontal, BlackKeysOutside, DrawBlackKeys: Boolean);
var
  Angle0, Angle1, KeyInnerRadius, KeyOuterRadius: Double;
  Color: TPianoRollColor;
  I: Integer;
  Note: TPianoRollNoteData;
begin
  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsNoteActiveAtTime(Note, TimeSeconds) or
      (Note.Key < LowestKey) or (Note.Key > HighestKey) or
      not IsPianoRollKeyVisible(Note.Key, Settings.KeyboardType) or
      (IsPianoBlackKey(Note.Key) <> DrawBlackKeys) then
      Continue;
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey, Settings.TrackColorMode,
      Settings.SingleTrackColor, Settings.GradientColor1,
      Settings.GradientColor2, Settings.Palette);
    if DrawBlackKeys then
    begin
      Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Note.Key) - 0.31,
        CenterPitch, PitchSpan, Horizontal);
      Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Note.Key) + 0.31,
        CenterPitch, PitchSpan, Horizontal);
      if BlackKeysOutside then
      begin
        KeyInnerRadius := Radius - Max(0.0, Settings.KeyLength) * 0.12;
        KeyOuterRadius := Radius + Max(0.0, Settings.KeyLength) * 0.50;
      end
      else
      begin
        KeyInnerRadius := Radius - Max(0.0, Settings.KeyLength) * 0.50;
        KeyOuterRadius := Radius + Max(0.0, Settings.KeyLength) * 0.12;
      end;
      AppendAnnularSector(Vertices, VertexCount, KeyInnerRadius,
        KeyOuterRadius, Angle0, Angle1, BlackFrontZ - 0.1, Color);
    end
    else
    begin
      Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Note.Key) - 0.48,
        CenterPitch, PitchSpan, Horizontal);
      Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Note.Key) + 0.48,
        CenterPitch, PitchSpan, Horizontal);
      AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
        Angle0, Angle1, WhiteFrontZ - 0.1, Color);
    end;
  end;
end;

procedure AppendRadialGlowPlane3D(var Vertices: TVertexColorArray;
  var VertexCount: Integer; CenterX, CenterY, CenterZ,
  AxisUX, AxisUY, AxisUZ, AxisVX, AxisVY, AxisVZ,
  RadiusU, RadiusV: Double; PeakAlpha: Integer;
  const Color: TPianoRollColor);
var
  C00, C01, C10, C11: TPianoRollColor;
  GridU, GridV: Integer;
  U0, U1, V0, V1: Double;
begin
  for GridV := -GLOW_GRID_HALF to GLOW_GRID_HALF - 1 do
    for GridU := -GLOW_GRID_HALF to GLOW_GRID_HALF - 1 do
    begin
      if VertexCount div 4 >= MAX_QUAD_COUNT - 1 then
        Exit;
      U0 := GridU / GLOW_GRID_HALF;
      U1 := (GridU + 1) / GLOW_GRID_HALF;
      V0 := GridV / GLOW_GRID_HALF;
      V1 := (GridV + 1) / GLOW_GRID_HALF;
      C00 := GetGlowVertexColor(Color, U0, V0, PeakAlpha);
      C01 := GetGlowVertexColor(Color, U0, V1, PeakAlpha);
      C10 := GetGlowVertexColor(Color, U1, V0, PeakAlpha);
      C11 := GetGlowVertexColor(Color, U1, V1, PeakAlpha);
      if (C00.A = 0) and (C01.A = 0) and
        (C10.A = 0) and (C11.A = 0) then
        Continue;
      EnsureVertexCapacity(Vertices, VertexCount + 8);
      SetVertex(Vertices[VertexCount],
        CenterX + AxisUX * U0 * RadiusU + AxisVX * V0 * RadiusV,
        CenterY + AxisUY * U0 * RadiusU + AxisVY * V0 * RadiusV,
        CenterZ + AxisUZ * U0 * RadiusU + AxisVZ * V0 * RadiusV, C00);
      SetVertex(Vertices[VertexCount + 1],
        CenterX + AxisUX * U0 * RadiusU + AxisVX * V1 * RadiusV,
        CenterY + AxisUY * U0 * RadiusU + AxisVY * V1 * RadiusV,
        CenterZ + AxisUZ * U0 * RadiusU + AxisVZ * V1 * RadiusV, C01);
      SetVertex(Vertices[VertexCount + 2],
        CenterX + AxisUX * U1 * RadiusU + AxisVX * V1 * RadiusV,
        CenterY + AxisUY * U1 * RadiusU + AxisVY * V1 * RadiusV,
        CenterZ + AxisUZ * U1 * RadiusU + AxisVZ * V1 * RadiusV, C11);
      SetVertex(Vertices[VertexCount + 3],
        CenterX + AxisUX * U1 * RadiusU + AxisVX * V0 * RadiusV,
        CenterY + AxisUY * U1 * RadiusU + AxisVY * V0 * RadiusV,
        CenterZ + AxisUZ * U1 * RadiusU + AxisVZ * V0 * RadiusV, C10);
      // 反対側から見ても消えないよう、同じ面を逆巻きでも追加する。
      Vertices[VertexCount + 4] := Vertices[VertexCount];
      Vertices[VertexCount + 5] := Vertices[VertexCount + 3];
      Vertices[VertexCount + 6] := Vertices[VertexCount + 2];
      Vertices[VertexCount + 7] := Vertices[VertexCount + 1];
      Inc(VertexCount, 8);
    end;
end;

procedure AppendCircularStrikeEffects(var Vertices: TVertexColorArray;
  var VertexCount: Integer; const Data: IPianoRollMusicData;
  TimeSeconds, InnerRadius, CenterPitch, PitchSpan, EffectZ: Double;
  LowestKey, HighestKey, MinTrack, MaxTrack, MinMusicKey,
  MaxMusicKey: Integer; const Settings: TPianoRollDisplaySettings;
  Horizontal: Boolean);
var
  CenterAngle, CenterX, CenterY, Elapsed, GlowExtent, Strength,
    TangentExtent: Double;
  Color: TPianoRollColor;
  GlowPlaneAlpha, I, PeakAlpha: Integer;
  Note: TPianoRollNoteData;
begin
  case Settings.StrikeEffectType of
    psetType1:
      ;
  else
    Exit;
  end;

  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsNoteActiveAtTime(Note, TimeSeconds) or
      (Note.Key < LowestKey) or (Note.Key > HighestKey) or
      not IsPianoRollKeyVisible(Note.Key, Settings.KeyboardType) then
      Continue;
    Elapsed := TimeSeconds - Note.StartSeconds;
    if (Elapsed < 0.0) or (Elapsed >= STRIKE_GLOW_DURATION) then
      Continue;

    Strength := 1.0 - Elapsed / STRIKE_GLOW_DURATION;
    PeakAlpha := Round(255 * Sqrt(Strength));
    GlowExtent := Max(10.0, Settings.KeyLength *
      (0.08 + (1.0 - Strength) * 0.05));
    CenterAngle := PitchToAngle(GetPianoKeyPitchCenter(Note.Key),
      CenterPitch, PitchSpan, Horizontal);
    TangentExtent := InnerRadius * 2.0 * Pi / PitchSpan *
      (0.38 + (1.0 - Strength) * 0.18);
    CenterX := Cos(CenterAngle) * InnerRadius;
    CenterY := Sin(CenterAngle) * InnerRadius;
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey, Settings.TrackColorMode,
      Settings.SingleTrackColor, Settings.GradientColor1,
      Settings.GradientColor2, Settings.Palette);
    GlowPlaneAlpha := Round(PeakAlpha * 0.55);
    // 円周位置ごとの接線・半径・時間軸から、直交する3つの発光面を作る。
    AppendRadialGlowPlane3D(Vertices, VertexCount,
      CenterX, CenterY, EffectZ,
      -Sin(CenterAngle), Cos(CenterAngle), 0.0,
      Cos(CenterAngle), Sin(CenterAngle), 0.0,
      TangentExtent, GlowExtent, GlowPlaneAlpha, Color);
    AppendRadialGlowPlane3D(Vertices, VertexCount,
      CenterX, CenterY, EffectZ,
      -Sin(CenterAngle), Cos(CenterAngle), 0.0,
      0.0, 0.0, 1.0,
      TangentExtent, GlowExtent, GlowPlaneAlpha, Color);
    AppendRadialGlowPlane3D(Vertices, VertexCount,
      CenterX, CenterY, EffectZ,
      Cos(CenterAngle), Sin(CenterAngle), 0.0,
      0.0, 0.0, 1.0,
      GlowExtent, GlowExtent, GlowPlaneAlpha, Color);
  end;
end;

procedure AppendCircularLanes(var Vertices: TVertexColorArray;
  var VertexCount: Integer; Radius, CenterPitch, PitchSpan, FutureZ: Double;
  LowestKey, HighestKey: Integer; const Settings: TPianoRollDisplaySettings;
  FaceOutward: Boolean);
var
  Angle0, Angle1, HalfWidth: Double;
  Color: TPianoRollColor;
  Key: Integer;
begin
  if not Settings.ShowLanes then
    Exit;
  if Settings.KeyboardType = pktHarp7 then
    HalfWidth := 0.48
  else
    HalfWidth := 0.31;
  for Key := LowestKey to HighestKey do
  begin
    if not IsPianoRollKeyVisible(Key, Settings.KeyboardType) then
      Continue;
    Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Key) - HalfWidth,
      CenterPitch, PitchSpan, False);
    Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Key) + HalfWidth,
      CenterPitch, PitchSpan, False);
    if IsPianoBlackKey(Key) then
      Color := Settings.Palette.BlackLane
    else
      Color := Settings.Palette.WhiteLane;
    // 内周表示と外周表示で頂点順を反転し、表示側へ面の法線を向ける。
    if FaceOutward then
      AppendCylindricalRibbon(Vertices, VertexCount, Radius, Angle1, Angle0,
        FutureZ, 0.0, Color)
    else
      AppendCylindricalRibbon(Vertices, VertexCount, Radius, Angle0, Angle1,
        FutureZ, 0.0, Color);
  end;
end;

procedure AppendCircularBeatRings(var Vertices: TVertexColorArray;
  var VertexCount: Integer; const Data: IPianoRollMusicData;
  TimeSeconds, FutureTime, DisplayTime, TimeAxisLength,
  Radius: Double; const Settings: TPianoRollDisplaySettings);
var
  Beat: TPianoRollBeatData;
  Color: TPianoRollColor;
  HalfWidth, TimeOffset, Z: Double;
  I: Integer;
begin
  if not Settings.ShowBeatLines then
    Exit;
  for I := 0 to Data.BeatCount - 1 do
  begin
    Beat := Data.Beats[I];
    TimeOffset := Beat.Seconds - TimeSeconds;
    if (TimeOffset < 0.0) or (TimeOffset > FutureTime) then
      Continue;
    if Beat.Index mod Max(1, Settings.BeatsPerMeasure) = 0 then
    begin
      Color := Settings.Palette.MeasureLine;
      HalfWidth := 1.5;
    end
    else
    begin
      Color := Settings.Palette.BeatLine;
      HalfWidth := 0.75;
    end;
    Z := -TimeOffset / DisplayTime * TimeAxisLength;
    AppendAnnularSector(Vertices, VertexCount,
      Max(1.0, Radius - HalfWidth), Radius + HalfWidth,
      0.0, 2.0 * Pi, Z, Color);
  end;
end;

procedure AppendHorizontalCircularKeyboard(var Vertices: TVertexColorArray;
  var VertexCount: Integer; Radius, CenterPitch, PitchSpan: Double;
  LowestKey, HighestKey: Integer; const Settings: TPianoRollDisplaySettings;
  FaceOutward: Boolean);
var
  Angle0, Angle1, BlackThickness, InnerRadius, KeyLength, OuterRadius,
  WhiteSurfaceRadius, WhiteThickness: Double;
  Key: Integer;
begin
  KeyLength := Max(1.0, Settings.KeyLength);
  WhiteThickness := Max(4.0, Max(0.0, Settings.WhiteKey3DThickness));
  BlackThickness := Max(2.0, Max(0.0, Settings.BlackKey3DThickness));
  if FaceOutward then
  begin
    InnerRadius := Radius;
    OuterRadius := Radius + WhiteThickness;
    WhiteSurfaceRadius := OuterRadius;
  end
  else
  begin
    InnerRadius := Max(1.0, Radius - WhiteThickness);
    OuterRadius := Radius;
    WhiteSurfaceRadius := InnerRadius;
  end;

  // 表示面と反対側の殻および前後端を閉じ、音階方向を接続した円筒帯を作る。
  if FaceOutward then
    AppendCylindricalRibbon(Vertices, VertexCount, InnerRadius, 0.0,
      2.0 * Pi, 0.0, KeyLength, ShadeColor(Settings.Palette.WhiteKey, 0.55))
  else
    AppendCylindricalRibbon(Vertices, VertexCount, OuterRadius, 2.0 * Pi,
      0.0, 0.0, KeyLength, ShadeColor(Settings.Palette.WhiteKey, 0.55));
  AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
    2.0 * Pi, 0.0, 0.0, ShadeColor(Settings.Palette.WhiteKey, 0.48));
  AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
    0.0, 2.0 * Pi, KeyLength, ShadeColor(Settings.Palette.WhiteKey, 0.42));

  // 白鍵の長さは円筒の奥行き方向へ割り当てる。
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      not IsPianoBlackKey(Key) then
    begin
      Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Key) - 0.48,
        CenterPitch, PitchSpan, True);
      Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Key) + 0.48,
        CenterPitch, PitchSpan, True);
      AppendCylindricalRibbon(Vertices, VertexCount, WhiteSurfaceRadius,
        Angle0, Angle1, 0.0, KeyLength, Settings.Palette.WhiteKey);
    end;

  // 黒鍵は白鍵の表示面から同じ方向へ押し出し、短い円筒面として重ねる。
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      IsPianoBlackKey(Key) then
    begin
      Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Key) - 0.31,
        CenterPitch, PitchSpan, True);
      Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Key) + 0.31,
        CenterPitch, PitchSpan, True);
      if FaceOutward then
        // 横用の音階角度は減少方向なので、外周面の法線を保つため入力順も反転する。
        AppendExtrudedCylindricalRibbon(Vertices, VertexCount,
          WhiteSurfaceRadius, Angle1, Angle0, 0.0, KeyLength * 0.62,
          BlackThickness, True, Settings.Palette.BlackKey)
      else
        AppendExtrudedCylindricalRibbon(Vertices, VertexCount,
          WhiteSurfaceRadius, Angle0, Angle1, 0.0, KeyLength * 0.62,
          BlackThickness, False, Settings.Palette.BlackKey);
    end;
end;

function DrawCircularPianoRoll3D(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings; Horizontal,
  Outward: Boolean): Boolean;
var
  Angle0, Angle1, CenterPitch, DisplayTime, EndSeconds, FutureTime: Double;
  BackZ, BlackFrontZ, FrontZ, InnerRadius, KeyHalfWidth, OuterRadius: Double;
  GuideSurfaceRadius, NoteSurfaceRadius, PastTime, PitchSpan, Radius,
    StrikeEffectZ, Time0, Time1, TimeAxisLength, WhiteSurfaceRadius: Double;
  Color: TPianoRollColor;
  Height, HighestKey, I, Key, LowestKey: Integer;
  HorizontalKeyboard, KeyboardFacesOutward, NoteFacesOutward,
    UseOuterSide: Boolean;
  MaxMusicKey, MaxTrack, MinMusicKey, MinTrack: Integer;
  Note: TPianoRollNoteData;
  Vertices: TVertexColorArray;
  VertexCount, Width: Integer;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or
    not Assigned(Video^.DrawPoly) or not Assigned(Data) then
    Exit;
  KeyboardFacesOutward := Horizontal and Outward;
  // 設定上のType2横とType3縦だけ表示を交換する。Type3横は外向き円筒へ分岐する。
  if Horizontal and not Outward then
  begin
    HorizontalKeyboard := False;
    UseOuterSide := True;
  end
  else if not Horizontal and Outward then
  begin
    HorizontalKeyboard := True;
    UseOuterSide := False;
  end
  else
  begin
    HorizontalKeyboard := Horizontal;
    UseOuterSide := Outward and not HorizontalKeyboard;
  end;
  NoteFacesOutward := UseOuterSide or KeyboardFacesOutward;
  // 円環側の音階角度は縦配置へ固定し、円筒鍵盤だけ専用の横角度を内部で使用する。
  Horizontal := False;
  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) then
    Exit;

  DisplayTime := Max(0.1, Settings.DisplayTime);
  FutureTime := Max(0.1, Settings.DisplayTime3D);
  TimeSeconds := TimeSeconds - Settings.TimeShift;
  ResolveEffectivePianoRollPitchRange(Data, TimeSeconds, FutureTime,
    Settings.CenterNote, Settings.VisibleNoteCount, Settings.PitchFollowMode,
    Settings.KeyboardType, LowestKey, HighestKey);
  GetPianoRollNoteRanges(Data, MinTrack, MaxTrack, MinMusicKey, MaxMusicKey);

  Radius := ResolveCircularPianoRollRadius(Width, Height, Settings,
    UseOuterSide or KeyboardFacesOutward);
  InnerRadius := Max(1.0, Radius - Max(0.0, Settings.KeyLength) * 0.5);
  OuterRadius := Radius + Max(0.0, Settings.KeyLength) * 0.5;
  if HorizontalKeyboard then
  begin
    // 円筒鍵盤は鍵盤長ではなく白鍵3D厚みが半径方向の表面位置を決める。
    // オフセット0のノート基準を、Type3縦は内周、Type3横は外周の白鍵面へ揃える。
    if KeyboardFacesOutward then
      WhiteSurfaceRadius := Radius +
        Max(4.0, Max(0.0, Settings.WhiteKey3DThickness))
    else
      WhiteSurfaceRadius := Radius -
        Max(4.0, Max(0.0, Settings.WhiteKey3DThickness));
    GuideSurfaceRadius := Max(1.0, WhiteSurfaceRadius);
  end
  else if UseOuterSide then
    GuideSurfaceRadius := OuterRadius
  else
    GuideSurfaceRadius := InnerRadius;
  if NoteFacesOutward then
    NoteSurfaceRadius := Max(1.0,
      GuideSurfaceRadius + Settings.NotePositionOffset)
  else
    NoteSurfaceRadius := Max(1.0,
      GuideSurfaceRadius - Settings.NotePositionOffset);
  CenterPitch := GetPianoKeyPitchCenter(
    EnsureRange(Settings.CenterNote, LowestKey, HighestKey));
  PitchSpan := Max(1.0,
    GetPianoKeyPitchCenter(HighestKey) -
    GetPianoKeyPitchCenter(LowestKey) + 1.0);
  TimeAxisLength := Max(1.0, Min(Width, Height) *
    Max(0.01, EnsureRange(Settings.StrikePosition, 0.0, 1.0)));
  PastTime := DisplayTime *
    (1.0 - EnsureRange(Settings.StrikePosition, 0.0, 1.0)) /
    Max(0.01, EnsureRange(Settings.StrikePosition, 0.0, 1.0));

  VertexCount := 0;
  SetLength(Vertices, 1024);

  AppendCircularLanes(Vertices, VertexCount, GuideSurfaceRadius, CenterPitch,
    PitchSpan, -FutureTime / DisplayTime * TimeAxisLength,
    LowestKey, HighestKey, Settings, NoteFacesOutward);
  AppendCircularBeatRings(Vertices, VertexCount, Data, TimeSeconds,
    FutureTime, DisplayTime, TimeAxisLength, GuideSurfaceRadius, Settings);

  // ノートを先に追加し、発音位置の円環鍵盤が前面へ重なる描画順を維持する。
  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if (Note.Key < LowestKey) or (Note.Key > HighestKey) or
      not IsPianoRollKeyVisible(Note.Key, Settings.KeyboardType) then
      Continue;
    EndSeconds := GetNoteEndSeconds(Note);
    Time0 := Max(-PastTime, Note.StartSeconds - TimeSeconds);
    Time1 := Min(FutureTime, EndSeconds - TimeSeconds);
    if Time1 <= Time0 then
      Continue;
    KeyHalfWidth := 0.31 * EnsureRange(Settings.NoteThickness, 0.05, 1.0);
    Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Note.Key) - KeyHalfWidth,
      CenterPitch, PitchSpan, Horizontal);
    Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Note.Key) + KeyHalfWidth,
      CenterPitch, PitchSpan, Horizontal);
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey, Settings.TrackColorMode,
      Settings.SingleTrackColor, Settings.GradientColor1,
      Settings.GradientColor2, Settings.Palette);
    // 各鍵盤の白鍵表示面を基準に、内向き／外向きへノートを接続する。
    AppendExtrudedCylindricalRibbon(Vertices, VertexCount, NoteSurfaceRadius,
      Angle0, Angle1,
      -Time1 / DisplayTime * TimeAxisLength,
      -Time0 / DisplayTime * TimeAxisLength, Settings.Note3DThickness,
      NoteFacesOutward, Color);
  end;

  if HorizontalKeyboard then
  begin
    AppendHorizontalCircularKeyboard(Vertices, VertexCount, Radius,
      CenterPitch, PitchSpan, LowestKey, HighestKey, Settings,
      KeyboardFacesOutward);
    StrikeEffectZ := 0.0;
  end
  else
  begin
    // 鍵盤の円環本体を先に作り、その後へ白鍵面と黒鍵を重ねる。
    FrontZ := -4.0;
    BackZ := FrontZ + Max(4.0, Max(0.0, Settings.WhiteKey3DThickness));
    AppendConnectedKeyboardBand(Vertices, VertexCount, InnerRadius,
      OuterRadius, FrontZ, BackZ, Settings.Palette.WhiteKey);

  // 白鍵上面は個別に描き、連続帯の上でも鍵の境界を維持する。
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      not IsPianoBlackKey(Key) then
    begin
      Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Key) - 0.48,
        CenterPitch, PitchSpan, Horizontal);
      Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Key) + 0.48,
        CenterPitch, PitchSpan, Horizontal);
      AppendAnnularSector(Vertices, VertexCount, InnerRadius, OuterRadius,
        Angle0, Angle1, FrontZ, Settings.Palette.WhiteKey);
    end;

  // 点灯した白鍵は黒鍵より先に重ね、通常の鍵盤重なりを維持する。
  AppendActiveCircularKeys(Vertices, VertexCount, Data, TimeSeconds,
    Radius, InnerRadius, OuterRadius, CenterPitch, PitchSpan,
    FrontZ, FrontZ, LowestKey, HighestKey, MinTrack, MaxTrack,
    MinMusicKey, MaxMusicKey, Settings, Horizontal, UseOuterSide, False);

  // 円環の表示方向に合わせ、内周または外周へ黒鍵を伸ばす。
  BlackFrontZ := FrontZ -
    Max(2.0, Max(0.0, Settings.BlackKey3DThickness));
  for Key := LowestKey to HighestKey do
    if IsPianoRollKeyVisible(Key, Settings.KeyboardType) and
      IsPianoBlackKey(Key) then
    begin
      Angle0 := PitchToAngle(GetPianoKeyPitchCenter(Key) - 0.31,
        CenterPitch, PitchSpan, Horizontal);
      Angle1 := PitchToAngle(GetPianoKeyPitchCenter(Key) + 0.31,
        CenterPitch, PitchSpan, Horizontal);
      if UseOuterSide then
        AppendExtrudedAnnularKey(Vertices, VertexCount,
          Radius - Max(0.0, Settings.KeyLength) * 0.12,
          Radius + Max(0.0, Settings.KeyLength) * 0.50,
          Angle0, Angle1, FrontZ, BlackFrontZ, Settings.Palette.BlackKey)
      else
        AppendExtrudedAnnularKey(Vertices, VertexCount,
          Radius - Max(0.0, Settings.KeyLength) * 0.50,
          Radius + Max(0.0, Settings.KeyLength) * 0.12,
          Angle0, Angle1, FrontZ, BlackFrontZ, Settings.Palette.BlackKey);
    end;

  // 発音中の黒鍵上面を最後にノート色で上書きする。
  AppendActiveCircularKeys(Vertices, VertexCount, Data, TimeSeconds,
    Radius, InnerRadius, OuterRadius, CenterPitch, PitchSpan,
    FrontZ, BlackFrontZ, LowestKey, HighestKey, MinTrack, MaxTrack,
    MinMusicKey, MaxMusicKey, Settings, Horizontal, UseOuterSide, True);

    StrikeEffectZ := Min(FrontZ, BlackFrontZ) - 0.35;
  end;

  // 円環／円筒とも、ノート接続位置のローカル3軸へ打鍵グローを配置する。
  AppendCircularStrikeEffects(Vertices, VertexCount, Data, TimeSeconds,
    NoteSurfaceRadius, CenterPitch, PitchSpan, StrikeEffectZ,
    LowestKey, HighestKey, MinTrack, MaxTrack, MinMusicKey, MaxMusicKey,
    Settings, Horizontal);

  if VertexCount > 0 then
    Result := Video^.DrawPoly(VERTEX_QUAD_COLOR, @Vertices[0],
      VertexCount, nil) <> 0
  else
    Result := True;
  if Result and Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(Width, Height);
end;

end.

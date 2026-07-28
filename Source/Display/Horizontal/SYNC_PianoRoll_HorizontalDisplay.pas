unit SYNC_PianoRoll_HorizontalDisplay;

// 時間方向を右向き、音階方向を上から下へ割り当てる横表示を実装する。

interface

uses
  SYNC_PianoRoll_DisplayTypes;

function CreateHorizontalPianoRollDisplay: IPianoRollDisplay;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_PianoRoll_Colors,
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_PianoKeys,
  SYNC_PianoRoll_PitchFollow,
  SYNC_PianoRoll_RGBA;

const
  STRIKE_GLOW_DURATION = 0.35;

type
  THorizontalPianoRollDisplay = class(TInterfacedObject, IPianoRollDisplay)
  private
    procedure DrawBeatLines(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds, PixelsPerSecond: Double;
      StrikePosition: Integer; const Settings: TPianoRollDisplaySettings);
    procedure DrawKeyboard(var Canvas: TPianoRollCanvas;
      StrikePosition, LowestKey, HighestKey: Integer;
      const Settings: TPianoRollDisplaySettings);
    procedure DrawKeyboardKey(var Canvas: TPianoRollCanvas;
      LeftPosition, TopPosition, RightPosition, BottomPosition: Integer;
      const Color: TPianoRollColor; Active: Boolean;
      const Settings: TPianoRollDisplaySettings);
    procedure DrawLanes(var Canvas: TPianoRollCanvas;
      StrikePosition, LowestKey, HighestKey: Integer;
      const Settings: TPianoRollDisplaySettings);
    procedure DrawActiveKeys(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      StrikePosition, LowestKey, HighestKey, MinTrack, MaxTrack,
      MinMusicKey, MaxMusicKey: Integer;
      const Settings: TPianoRollDisplaySettings);
    procedure DrawStrikeGlow(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      StrikePosition, LowestKey, HighestKey, MinTrack, MaxTrack,
      MinMusicKey, MaxMusicKey: Integer;
      const Settings: TPianoRollDisplaySettings);
    procedure DrawNote(var Canvas: TPianoRollCanvas;
      LeftPosition, TopPosition, RightPosition, BottomPosition: Integer;
      const Color: TPianoRollColor;
      const Settings: TPianoRollDisplaySettings);
    procedure GetKeyAxisBounds(CanvasHeight, MidiKey, LowestKey,
      HighestKey: Integer; KeyThickness: Double;
      out StartPosition, EndPosition: Integer);
  public
    procedure Draw(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      const Settings: TPianoRollDisplaySettings);
  end;

procedure THorizontalPianoRollDisplay.DrawKeyboardKey(
  var Canvas: TPianoRollCanvas; LeftPosition, TopPosition,
  RightPosition, BottomPosition: Integer; const Color: TPianoRollColor;
  Active: Boolean; const Settings: TPianoRollDisplaySettings);
var
  Bevel, GlossAlpha, GlossBottom: Integer;
begin
  if (RightPosition - LeftPosition < 4) or
    (BottomPosition - TopPosition < 4) then
  begin
    Canvas.FillRectangle(LeftPosition, TopPosition, RightPosition,
      BottomPosition, Color);
    Exit;
  end;

  Bevel := Min(ScalePianoRollThickness(1, Settings.KeyThickness),
    Min((RightPosition - LeftPosition) div 3,
      (BottomPosition - TopPosition) div 3));
  Bevel := Max(1, Bevel);
  Canvas.FillRectangle(LeftPosition, TopPosition, RightPosition,
    BottomPosition, DarkenPianoRollColor(Color, 0.35));
  Canvas.FillRectangle(LeftPosition + Bevel, TopPosition + Bevel,
    RightPosition - Bevel, BottomPosition - Bevel, Color);
  Canvas.FillRectangle(LeftPosition, TopPosition, RightPosition - Bevel,
    TopPosition + Bevel, LightenPianoRollColor(Color, 0.28));
  Canvas.FillRectangle(LeftPosition, TopPosition + Bevel,
    LeftPosition + Bevel, BottomPosition - Bevel,
    LightenPianoRollColor(Color, 0.18));
  Canvas.FillRectangle(LeftPosition + Bevel, BottomPosition - Bevel,
    RightPosition, BottomPosition, DarkenPianoRollColor(Color, 0.22));
  Canvas.FillRectangle(RightPosition - Bevel, TopPosition + Bevel,
    RightPosition, BottomPosition, DarkenPianoRollColor(Color, 0.30));

  GlossBottom := TopPosition + Bevel +
    Max(1, (BottomPosition - TopPosition - Bevel * 2) div 3);
  if Active then
    GlossAlpha := 70
  else
    GlossAlpha := 30;
  Canvas.BlendRectangle(LeftPosition + Bevel, TopPosition + Bevel,
    RightPosition - Bevel, GlossBottom,
    PianoRollColor(255, 255, 255, GlossAlpha));
end;

procedure THorizontalPianoRollDisplay.DrawNote(var Canvas: TPianoRollCanvas;
  LeftPosition, TopPosition, RightPosition, BottomPosition: Integer;
  const Color: TPianoRollColor;
  const Settings: TPianoRollDisplaySettings);
var
  Bevel, GlossBottom: Integer;
begin
  if (not Settings.NoteDepthEnabled) or
    (RightPosition - LeftPosition < 4) or
    (BottomPosition - TopPosition < 4) then
  begin
    Canvas.FillRectangle(LeftPosition, TopPosition, RightPosition,
      BottomPosition, Color);
    Exit;
  end;

  Bevel := Min(ScalePianoRollThickness(1, Settings.KeyThickness),
    Min((RightPosition - LeftPosition) div 3,
      (BottomPosition - TopPosition) div 3));
  Bevel := Max(1, Bevel);
  Canvas.FillRectangle(LeftPosition, TopPosition, RightPosition,
    BottomPosition, DarkenPianoRollColor(Color, 0.45));
  Canvas.FillRectangle(LeftPosition + Bevel, TopPosition + Bevel,
    RightPosition - Bevel, BottomPosition - Bevel, Color);
  Canvas.FillRectangle(LeftPosition, TopPosition, RightPosition - Bevel,
    TopPosition + Bevel, LightenPianoRollColor(Color, 0.35));
  Canvas.FillRectangle(LeftPosition, TopPosition + Bevel,
    LeftPosition + Bevel, BottomPosition - Bevel,
    LightenPianoRollColor(Color, 0.18));
  Canvas.FillRectangle(LeftPosition + Bevel, BottomPosition - Bevel,
    RightPosition, BottomPosition, DarkenPianoRollColor(Color, 0.30));
  Canvas.FillRectangle(RightPosition - Bevel, TopPosition + Bevel,
    RightPosition, BottomPosition, DarkenPianoRollColor(Color, 0.30));

  // 横表示は上側へ細い反射を置き、進行方向に伸びる面を見せる。
  GlossBottom := TopPosition + Bevel +
    Max(1, (BottomPosition - TopPosition - Bevel * 2) div 3);
  Canvas.BlendRectangle(LeftPosition + Bevel, TopPosition + Bevel,
    RightPosition - Bevel, GlossBottom,
    PianoRollColor(255, 255, 255, 60));
end;

function IsNoteActiveAtTime(const Note: TPianoRollNoteData;
  TimeSeconds: Double): Boolean;
var
  EndSeconds: Double;
begin
  // 発音開始の一瞬だけでなく打鍵中を点灯し、短いノートも映像上で認識できるようにする。
  EndSeconds := Note.EndSeconds;
  if EndSeconds < Note.StartSeconds then
    EndSeconds := Note.StartSeconds + 0.2;
  Result := (TimeSeconds >= Note.StartSeconds) and
    (TimeSeconds < EndSeconds);
end;

procedure THorizontalPianoRollDisplay.DrawActiveKeys(
  var Canvas: TPianoRollCanvas; const Data: IPianoRollMusicData;
  TimeSeconds: Double; StrikePosition, LowestKey, HighestKey, MinTrack,
  MaxTrack, MinMusicKey, MaxMusicKey: Integer;
  const Settings: TPianoRollDisplaySettings);
var
  Color: TPianoRollColor;
  EndPosition, I, Key, StartPosition: Integer;
  KeyboardLeft, KeyboardRight: Integer;
  Note: TPianoRollNoteData;
begin
  if Settings.KeyLength <= 0 then
    Exit;
  KeyboardRight := StrikePosition - 2;
  KeyboardLeft := KeyboardRight - Round(Settings.KeyLength);
  // 発音中の白鍵を先に描き、通常時と同じく黒鍵が上へ重なる形を維持する。
  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsNoteActiveAtTime(Note, TimeSeconds) or
      (Note.Key < LowestKey) or (Note.Key > HighestKey) or
      IsPianoBlackKey(Note.Key) then
      Continue;
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey,
      Settings.TrackColorMode, Settings.SingleTrackColor,
      Settings.GradientColor1, Settings.GradientColor2, Settings.Palette);
    GetKeyAxisBounds(Canvas.Height, Note.Key, LowestKey, HighestKey,
      Settings.KeyThickness, StartPosition, EndPosition);
    DrawKeyboardKey(Canvas, KeyboardLeft, StartPosition, KeyboardRight,
      EndPosition, Color, True, Settings);
  end;

  // 白鍵の点灯で覆われた隣接黒鍵を復元する。
  for Key := LowestKey to HighestKey do
    if IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      DrawKeyboardKey(Canvas,
        KeyboardLeft, StartPosition,
        KeyboardLeft + Round(Settings.KeyLength * 0.62), EndPosition,
        Settings.Palette.BlackKey, False, Settings);
    end;

  // 発音中の黒鍵は復元した通常黒鍵よりさらに上へ描く。
  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsNoteActiveAtTime(Note, TimeSeconds) or
      (Note.Key < LowestKey) or (Note.Key > HighestKey) or
      not IsPianoBlackKey(Note.Key) then
      Continue;
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey,
      Settings.TrackColorMode, Settings.SingleTrackColor,
      Settings.GradientColor1, Settings.GradientColor2, Settings.Palette);
    GetKeyAxisBounds(Canvas.Height, Note.Key, LowestKey, HighestKey,
      Settings.KeyThickness, StartPosition, EndPosition);
    DrawKeyboardKey(Canvas,
      KeyboardLeft, StartPosition,
      KeyboardLeft + Round(Settings.KeyLength * 0.62), EndPosition,
      Color, True, Settings);
  end;
end;

procedure THorizontalPianoRollDisplay.DrawStrikeGlow(
  var Canvas: TPianoRollCanvas; const Data: IPianoRollMusicData;
  TimeSeconds: Double; StrikePosition, LowestKey, HighestKey, MinTrack,
  MaxTrack, MinMusicKey, MaxMusicKey: Integer;
  const Settings: TPianoRollDisplaySettings);
var
  Color: TPianoRollColor;
  Elapsed, Strength: Double;
  EndPosition, I, PeakAlpha, Radius, StartPosition: Integer;
  Note: TPianoRollNoteData;
begin
  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if not IsNoteActiveAtTime(Note, TimeSeconds) or
      (Note.Key < LowestKey) or (Note.Key > HighestKey) then
      Continue;
    Elapsed := TimeSeconds - Note.StartSeconds;
    if (Elapsed < 0.0) or (Elapsed >= STRIKE_GLOW_DURATION) then
      Continue;
    Strength := 1.0 - Elapsed / STRIKE_GLOW_DURATION;
    Radius := Max(16, Round(Settings.KeyThickness *
      (2.4 + (1.0 - Strength) * 0.8)));
    PeakAlpha := Round(255 * Sqrt(Strength));
    GetKeyAxisBounds(Canvas.Height, Note.Key, LowestKey, HighestKey,
      Settings.KeyThickness, StartPosition, EndPosition);
    Color := ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
      MinTrack, MaxTrack, MinMusicKey, MaxMusicKey,
      Settings.TrackColorMode, Settings.SingleTrackColor,
      Settings.GradientColor1, Settings.GradientColor2, Settings.Palette);
    Canvas.BlendRadialGlow(
      StrikePosition + Max(1, Round(Settings.KeyThickness * 0.12)),
      (StartPosition + EndPosition) div 2,
      Radius, Radius, PeakAlpha, Color);
  end;
end;

procedure THorizontalPianoRollDisplay.DrawBeatLines(
  var Canvas: TPianoRollCanvas; const Data: IPianoRollMusicData;
  TimeSeconds, PixelsPerSecond: Double; StrikePosition: Integer;
  const Settings: TPianoRollDisplaySettings);
var
  Beat: TPianoRollBeatData;
  BeatPosition, I, LineThickness, MeasureLength: Integer;
  LineColor: TPianoRollColor;
begin
  if not Settings.ShowBeatLines then
    Exit;
  MeasureLength := Max(1, Settings.BeatsPerMeasure);
  for I := 0 to Data.BeatCount - 1 do
  begin
    Beat := Data.Beats[I];
    BeatPosition := StrikePosition +
      Round((Beat.Seconds - TimeSeconds) * PixelsPerSecond);
    if (BeatPosition <= StrikePosition) or
      (BeatPosition >= Canvas.Width) then
      Continue;

    if (Beat.Index mod MeasureLength) = 0 then
    begin
      LineColor := Settings.Palette.MeasureLine;
      LineThickness := ScalePianoRollThickness(2, Settings.KeyThickness);
    end
    else
    begin
      LineColor := Settings.Palette.BeatLine;
      LineThickness := ScalePianoRollThickness(1, Settings.KeyThickness);
    end;
    Canvas.FillRectangle(BeatPosition, 0,
      BeatPosition + LineThickness, Canvas.Height, LineColor);
  end;
end;

procedure THorizontalPianoRollDisplay.GetKeyAxisBounds(CanvasHeight,
  MidiKey, LowestKey, HighestKey: Integer; KeyThickness: Double;
  out StartPosition, EndPosition: Integer);
var
  AxisCenter, KeyCenter, RangeCenter, VisibleThickness: Double;
begin
  KeyThickness := Max(1.0, KeyThickness);
  RangeCenter := (GetPianoKeyPitchCenter(LowestKey) +
    GetPianoKeyPitchCenter(HighestKey)) * 0.5;
  KeyCenter := GetPianoKeyPitchCenter(MidiKey);
  // 横表示は高音ほど画面上側へ配置する。
  AxisCenter := CanvasHeight * 0.5 -
    (KeyCenter - RangeCenter) * KeyThickness;
  if IsPianoBlackKey(MidiKey) then
    VisibleThickness := KeyThickness * 0.62
  else
    VisibleThickness := KeyThickness;
  StartPosition := Round(AxisCenter - VisibleThickness * 0.5);
  EndPosition := Round(AxisCenter + VisibleThickness * 0.5);
  if EndPosition <= StartPosition then
    EndPosition := StartPosition + 1;
end;

procedure THorizontalPianoRollDisplay.DrawLanes(
  var Canvas: TPianoRollCanvas; StrikePosition, LowestKey,
  HighestKey: Integer; const Settings: TPianoRollDisplaySettings);
var
  EndPosition, Key, StartPosition: Integer;
begin
  if not Settings.ShowLanes then
    Exit;

  // 背景レーンは鍵盤の白黒によらず同じ幅とし、各鍵盤の中心へ揃える。
  for Key := LowestKey to HighestKey do
    if not IsPianoBlackKey(Key) then
    begin
      GetPianoRollNoteAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, 1.0, True, StartPosition, EndPosition);
      Canvas.FillRectangle(StrikePosition, StartPosition, Canvas.Width,
        EndPosition, Settings.Palette.WhiteLane);
    end;

  for Key := LowestKey to HighestKey do
    if IsPianoBlackKey(Key) then
    begin
      GetPianoRollNoteAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, 1.0, True, StartPosition, EndPosition);
      Canvas.FillRectangle(StrikePosition, StartPosition, Canvas.Width,
        EndPosition, Settings.Palette.BlackLane);
    end;
end;

procedure THorizontalPianoRollDisplay.DrawKeyboard(
  var Canvas: TPianoRollCanvas; StrikePosition, LowestKey,
  HighestKey: Integer; const Settings: TPianoRollDisplaySettings);
var
  EndPosition, Key, StartPosition: Integer;
  KeyboardLeft, KeyboardRight: Integer;
begin
  if Settings.KeyLength <= 0 then
    Exit;
  KeyboardRight := StrikePosition - 2;
  KeyboardLeft := KeyboardRight - Round(Settings.KeyLength);

  // 白鍵を先に並べ、浅い面取りと横方向の反射を付ける。
  for Key := LowestKey to HighestKey do
    if not IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      DrawKeyboardKey(Canvas, KeyboardLeft, StartPosition, KeyboardRight,
        EndPosition, Settings.Palette.WhiteKey, False, Settings);
    end;

  // 水平のピアノを左へ90度回した向きに合わせ、黒鍵は左側へ寄せる。
  for Key := LowestKey to HighestKey do
    if IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      DrawKeyboardKey(Canvas,
        KeyboardLeft, StartPosition,
        KeyboardLeft + Round(Settings.KeyLength * 0.62), EndPosition,
        Settings.Palette.BlackKey, False, Settings);
    end;
end;

procedure THorizontalPianoRollDisplay.Draw(var Canvas: TPianoRollCanvas;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings);
var
  BottomPosition, EndPosition, I: Integer;
  NoteBottom, NoteTop: Integer;
  LeftPosition, RightPosition, StartPosition, StrikePosition: Integer;
  EndSeconds, PixelsPerSecond: Double;
  HighestKey, LowestKey, MaxMusicKey, MaxTrack, MinMusicKey, MinTrack: Integer;
  Note: TPianoRollNoteData;
begin
  if not Assigned(Data) or (Canvas.Width <= 0) or (Canvas.Height <= 0) then
    Exit;

  TimeSeconds := TimeSeconds - Settings.TimeShift;
  ResolveEffectivePianoRollPitchRange(Data, TimeSeconds,
    Settings.DisplayTime, Settings.CenterNote, Settings.VisibleNoteCount,
    Settings.PitchFollowMode, LowestKey, HighestKey);
  GetPianoRollNoteRanges(Data, MinTrack, MaxTrack, MinMusicKey, MaxMusicKey);
  // 共通の80%は発音位置から未来側に確保する時間方向の割合を表す。
  StrikePosition := EnsureRange(
    Round(Canvas.Width * (1.0 - Settings.StrikePosition)),
    0, Canvas.Width - 1);
  DrawLanes(Canvas, StrikePosition, LowestKey, HighestKey, Settings);
  PixelsPerSecond := 0.0;
  if Settings.DisplayTime > 0 then
  begin
    PixelsPerSecond := Max(1, Canvas.Width - StrikePosition) /
      Settings.DisplayTime;
    DrawBeatLines(Canvas, Data, TimeSeconds, PixelsPerSecond,
      StrikePosition, Settings);
  end;
  DrawKeyboard(Canvas, StrikePosition, LowestKey, HighestKey, Settings);
  DrawActiveKeys(Canvas, Data, TimeSeconds, StrikePosition,
    LowestKey, HighestKey, MinTrack, MaxTrack, MinMusicKey, MaxMusicKey,
    Settings);
  Canvas.FillRectangle(StrikePosition, 0, StrikePosition +
    ScalePianoRollThickness(2, Settings.KeyThickness),
    Canvas.Height, Settings.Palette.StrikeLine);

  if Settings.DisplayTime <= 0 then
    Exit;

  for I := 0 to Data.NoteCount - 1 do
  begin
    Note := Data.Notes[I];
    if (Note.Key < LowestKey) or (Note.Key > HighestKey) then
      Continue;
    EndSeconds := Note.EndSeconds;
    if EndSeconds < Note.StartSeconds then
      EndSeconds := Note.StartSeconds + 0.2;
    if EndSeconds < TimeSeconds then
      Continue;

    StartPosition := StrikePosition +
      Round((Note.StartSeconds - TimeSeconds) * PixelsPerSecond);
    EndPosition := StrikePosition +
      Round((EndSeconds - TimeSeconds) * PixelsPerSecond);
    LeftPosition := Max(StrikePosition, Min(StartPosition, EndPosition));
    RightPosition := Max(StartPosition, EndPosition);
    if (RightPosition < 0) or (LeftPosition >= Canvas.Width) then
      Continue;

    GetPianoRollNoteAxisBounds(Canvas.Height, Note.Key, LowestKey, HighestKey,
      Settings.KeyThickness, Settings.NoteThickness, True,
      NoteTop, NoteBottom);
    BottomPosition := Max(NoteTop + 1, NoteBottom);
    DrawNote(Canvas, LeftPosition, NoteTop,
      Max(LeftPosition + 1, RightPosition), BottomPosition,
      ResolvePianoRollTrackColor(Note.TrackIndex, Note.Key,
        MinTrack, MaxTrack, MinMusicKey, MaxMusicKey,
        Settings.TrackColorMode, Settings.SingleTrackColor,
        Settings.GradientColor1, Settings.GradientColor2,
        Settings.Palette), Settings);
  end;
  DrawStrikeGlow(Canvas, Data, TimeSeconds, StrikePosition,
    LowestKey, HighestKey, MinTrack, MaxTrack, MinMusicKey, MaxMusicKey,
    Settings);
end;

function CreateHorizontalPianoRollDisplay: IPianoRollDisplay;
begin
  Result := THorizontalPianoRollDisplay.Create;
end;

end.

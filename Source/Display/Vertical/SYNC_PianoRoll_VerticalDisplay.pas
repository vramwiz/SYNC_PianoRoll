unit SYNC_PianoRoll_VerticalDisplay;

// 時間方向を下向き、音階方向を左から右へ割り当てる縦表示を実装する。

interface

uses
  SYNC_PianoRoll_DisplayTypes;

function CreateVerticalPianoRollDisplay: IPianoRollDisplay;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_PianoRoll_MusicData,
  SYNC_PianoRoll_PianoKeys,
  SYNC_PianoRoll_RGBA;

type
  TVerticalPianoRollDisplay = class(TInterfacedObject, IPianoRollDisplay)
  private
    procedure DrawBeatLines(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds, PixelsPerSecond: Double;
      StrikePosition: Integer; const Settings: TPianoRollDisplaySettings);
    procedure DrawKeyboard(var Canvas: TPianoRollCanvas;
      StrikePosition, LowestKey, HighestKey: Integer;
      const Settings: TPianoRollDisplaySettings);
    procedure DrawLanes(var Canvas: TPianoRollCanvas;
      StrikePosition, LowestKey, HighestKey: Integer;
      const Settings: TPianoRollDisplaySettings);
    procedure GetKeyAxisBounds(CanvasWidth, MidiKey, LowestKey,
      HighestKey: Integer; KeyThickness: Double;
      out StartPosition, EndPosition: Integer);
    function GetTrackColor(TrackIndex: Integer): TPianoRollColor;
    procedure ResolveKeyRange(const Data: IPianoRollMusicData;
      const Settings: TPianoRollDisplaySettings;
      out LowestKey, HighestKey: Integer);
  public
    procedure Draw(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      const Settings: TPianoRollDisplaySettings);
  end;

function TVerticalPianoRollDisplay.GetTrackColor(
  TrackIndex: Integer): TPianoRollColor;
var
  ColorIndex: Integer;
begin
  ColorIndex := TrackIndex mod 6;
  if ColorIndex < 0 then
    Inc(ColorIndex, 6);
  case ColorIndex of
    0: Result := PianoRollColor(80, 210, 255, 255);
    1: Result := PianoRollColor(255, 120, 180, 255);
    2: Result := PianoRollColor(120, 235, 140, 255);
    3: Result := PianoRollColor(255, 205, 80, 255);
    4: Result := PianoRollColor(175, 130, 255, 255);
  else
    Result := PianoRollColor(255, 145, 75, 255);
  end;
  end;

procedure TVerticalPianoRollDisplay.DrawBeatLines(
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
    BeatPosition := StrikePosition -
      Round((Beat.Seconds - TimeSeconds) * PixelsPerSecond);
    if (BeatPosition < 0) or (BeatPosition >= StrikePosition) then
      Continue;

    if (Beat.Index mod MeasureLength) = 0 then
    begin
      LineColor := PianoRollColor(255, 190, 80, 120);
      LineThickness := 2;
    end
    else
    begin
      LineColor := PianoRollColor(255, 255, 255, 48);
      LineThickness := 1;
    end;
    Canvas.FillRectangle(0, BeatPosition, Canvas.Width,
      BeatPosition + LineThickness, LineColor);
  end;
end;

procedure TVerticalPianoRollDisplay.GetKeyAxisBounds(CanvasWidth, MidiKey,
  LowestKey, HighestKey: Integer; KeyThickness: Double;
  out StartPosition, EndPosition: Integer);
var
  AxisCenter, KeyCenter, RangeCenter, VisibleThickness: Double;
begin
  KeyThickness := Max(1.0, KeyThickness);
  RangeCenter := (GetPianoKeyPitchCenter(LowestKey) +
    GetPianoKeyPitchCenter(HighestKey)) * 0.5;
  KeyCenter := GetPianoKeyPitchCenter(MidiKey);
  AxisCenter := CanvasWidth * 0.5 +
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

procedure TVerticalPianoRollDisplay.DrawLanes(
  var Canvas: TPianoRollCanvas; StrikePosition, LowestKey,
  HighestKey: Integer; const Settings: TPianoRollDisplaySettings);
var
  EndPosition, Key, StartPosition: Integer;
begin
  if not Settings.ShowLanes then
    Exit;

  // 白鍵レーンを敷き、黒鍵レーンを白鍵の境界へ重ねる。
  for Key := LowestKey to HighestKey do
    if not IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Width, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      Canvas.FillRectangle(StartPosition, 0, EndPosition, StrikePosition,
        PianoRollColor(238, 238, 242, 28));
    end;

  for Key := LowestKey to HighestKey do
    if IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Width, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      Canvas.FillRectangle(StartPosition, 0, EndPosition, StrikePosition,
        PianoRollColor(110, 110, 120, 24));
    end;
end;

procedure TVerticalPianoRollDisplay.ResolveKeyRange(
  const Data: IPianoRollMusicData;
  const Settings: TPianoRollDisplaySettings;
  out LowestKey, HighestKey: Integer);
var
  I: Integer;
  Note: TPianoRollNoteData;
begin
  LowestKey := EnsureRange(Settings.LowestKey, 0, 127);
  HighestKey := EnsureRange(Settings.HighestKey, LowestKey, 127);
  if Settings.AutoKeyRange and Assigned(Data) and
    (Data.NoteCount > 0) then
  begin
    LowestKey := 127;
    HighestKey := 0;
    for I := 0 to Data.NoteCount - 1 do
    begin
      Note := Data.Notes[I];
      LowestKey := Min(LowestKey, EnsureRange(Note.Key, 0, 127));
      HighestKey := Max(HighestKey, EnsureRange(Note.Key, 0, 127));
    end;
  end;

  // 音域端が黒鍵でも、その下にある白鍵の土台を必ず含める。
  while (LowestKey > 0) and IsPianoBlackKey(LowestKey) do
    Dec(LowestKey);
  while (HighestKey < 127) and IsPianoBlackKey(HighestKey) do
    Inc(HighestKey);
end;

procedure TVerticalPianoRollDisplay.DrawKeyboard(
  var Canvas: TPianoRollCanvas; StrikePosition, LowestKey,
  HighestKey: Integer; const Settings: TPianoRollDisplaySettings);
var
  EndPosition, Key, StartPosition: Integer;
  KeyboardBottom, KeyboardTop: Integer;
begin
  if Settings.KeyLength <= 0 then
    Exit;
  KeyboardTop := StrikePosition + 2;
  KeyboardBottom := KeyboardTop + Round(Settings.KeyLength);

  // 白鍵を先に並べ、境界線を付ける。
  for Key := LowestKey to HighestKey do
    if not IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Width, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      Canvas.FillRectangle(StartPosition, KeyboardTop, EndPosition,
        KeyboardBottom, PianoRollColor(242, 242, 242, 255));
      Canvas.FillRectangle(StartPosition, KeyboardTop, StartPosition + 1,
        KeyboardBottom, PianoRollColor(72, 72, 72, 255));
    end;

  // 黒鍵は白鍵の上へ重ねる。
  for Key := LowestKey to HighestKey do
    if IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Width, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      Canvas.FillRectangle(StartPosition, KeyboardTop, EndPosition,
        KeyboardTop + Round(Settings.KeyLength * 0.62),
        PianoRollColor(24, 24, 24, 255));
    end;
end;

procedure TVerticalPianoRollDisplay.Draw(var Canvas: TPianoRollCanvas;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings);
var
  BottomPosition, EndPosition, I: Integer;
  LaneLeft, LaneRight, NoteLeft, NoteRight: Integer;
  StartPosition, StrikePosition, TopPosition: Integer;
  EndSeconds, PixelsPerSecond, Thickness: Double;
  HighestKey, LowestKey: Integer;
  Note: TPianoRollNoteData;
begin
  if not Assigned(Data) or (Canvas.Width <= 0) or (Canvas.Height <= 0) then
    Exit;

  ResolveKeyRange(Data, Settings, LowestKey, HighestKey);
  StrikePosition := EnsureRange(
    Round(Canvas.Height * Settings.StrikePosition), 0, Canvas.Height - 1);
  DrawLanes(Canvas, StrikePosition, LowestKey, HighestKey, Settings);
  TimeSeconds := TimeSeconds - Settings.TimeShift;
  PixelsPerSecond := 0.0;
  if Settings.DisplayTime > 0 then
  begin
    PixelsPerSecond := Max(1, StrikePosition) / Settings.DisplayTime;
    DrawBeatLines(Canvas, Data, TimeSeconds, PixelsPerSecond,
      StrikePosition, Settings);
  end;
  DrawKeyboard(Canvas, StrikePosition, LowestKey, HighestKey, Settings);
  Canvas.FillRectangle(0, StrikePosition, Canvas.Width, StrikePosition + 2,
    PianoRollColor(255, 255, 255, 160));

  if Settings.DisplayTime <= 0 then
    Exit;
  Thickness := EnsureRange(Settings.NoteThickness, 0.05, 1.0);

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

    StartPosition := StrikePosition -
      Round((Note.StartSeconds - TimeSeconds) * PixelsPerSecond);
    EndPosition := StrikePosition -
      Round((EndSeconds - TimeSeconds) * PixelsPerSecond);
    TopPosition := Min(StartPosition, EndPosition);
    BottomPosition := Min(StrikePosition, Max(StartPosition, EndPosition));
    if (BottomPosition < 0) or (TopPosition >= Canvas.Height) then
      Continue;

    GetKeyAxisBounds(Canvas.Width, Note.Key, LowestKey, HighestKey,
      Settings.KeyThickness, LaneLeft, LaneRight);
    NoteLeft := LaneLeft +
      Round((LaneRight - LaneLeft) * (1.0 - Thickness) / 2.0);
    NoteRight := LaneRight -
      Round((LaneRight - LaneLeft) * (1.0 - Thickness) / 2.0);
    Canvas.FillRectangle(NoteLeft, TopPosition, Max(NoteLeft + 1, NoteRight),
      BottomPosition, GetTrackColor(Note.TrackIndex));
  end;
end;

function CreateVerticalPianoRollDisplay: IPianoRollDisplay;
begin
  Result := TVerticalPianoRollDisplay.Create;
end;

end.

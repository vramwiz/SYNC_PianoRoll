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
  SYNC_PianoRoll_RGBA;

type
  THorizontalPianoRollDisplay = class(TInterfacedObject, IPianoRollDisplay)
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
    procedure GetKeyAxisBounds(CanvasHeight, MidiKey, LowestKey,
      HighestKey: Integer; KeyThickness: Double;
      out StartPosition, EndPosition: Integer);
  public
    procedure Draw(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      const Settings: TPianoRollDisplaySettings);
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

  // 白鍵レーンを敷き、黒鍵レーンを白鍵の境界へ重ねる。
  for Key := LowestKey to HighestKey do
    if not IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      Canvas.FillRectangle(StrikePosition, StartPosition, Canvas.Width,
        EndPosition, Settings.Palette.WhiteLane);
    end;

  for Key := LowestKey to HighestKey do
    if IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
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

  // 白鍵を先に並べ、音階方向の境界線を付ける。
  for Key := LowestKey to HighestKey do
    if not IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      Canvas.FillRectangle(KeyboardLeft, StartPosition, KeyboardRight,
        EndPosition, Settings.Palette.WhiteKey);
      Canvas.FillRectangle(KeyboardLeft, StartPosition, KeyboardRight,
        StartPosition + ScalePianoRollThickness(
          1, Settings.KeyThickness), Settings.Palette.KeyBorder);
    end;

  // 黒鍵は発音位置側へ寄せ、白鍵の上へ重ねる。
  for Key := LowestKey to HighestKey do
    if IsPianoBlackKey(Key) then
    begin
      GetKeyAxisBounds(Canvas.Height, Key, LowestKey, HighestKey,
        Settings.KeyThickness, StartPosition, EndPosition);
      Canvas.FillRectangle(
        KeyboardRight - Round(Settings.KeyLength * 0.62),
        StartPosition, KeyboardRight, EndPosition,
        Settings.Palette.BlackKey);
    end;
end;

procedure THorizontalPianoRollDisplay.Draw(var Canvas: TPianoRollCanvas;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings);
var
  BottomPosition, EndPosition, I: Integer;
  LaneBottom, LaneTop, NoteBottom, NoteTop: Integer;
  LeftPosition, RightPosition, StartPosition, StrikePosition: Integer;
  EndSeconds, PixelsPerSecond, Thickness: Double;
  HighestKey, LowestKey: Integer;
  Note: TPianoRollNoteData;
begin
  if not Assigned(Data) or (Canvas.Width <= 0) or (Canvas.Height <= 0) then
    Exit;

  // 現在は基準音域をそのまま実効音域とし、追従方式は後から接続する。
  ResolvePianoRollPitchRange(Settings.CenterNote, Settings.VisibleNoteCount,
    LowestKey, HighestKey);
  // 共通の80%は発音位置から未来側に確保する時間方向の割合を表す。
  StrikePosition := EnsureRange(
    Round(Canvas.Width * (1.0 - Settings.StrikePosition)),
    0, Canvas.Width - 1);
  DrawLanes(Canvas, StrikePosition, LowestKey, HighestKey, Settings);
  TimeSeconds := TimeSeconds - Settings.TimeShift;
  PixelsPerSecond := 0.0;
  if Settings.DisplayTime > 0 then
  begin
    PixelsPerSecond := Max(1, Canvas.Width - StrikePosition) /
      Settings.DisplayTime;
    DrawBeatLines(Canvas, Data, TimeSeconds, PixelsPerSecond,
      StrikePosition, Settings);
  end;
  DrawKeyboard(Canvas, StrikePosition, LowestKey, HighestKey, Settings);
  Canvas.FillRectangle(StrikePosition, 0, StrikePosition +
    ScalePianoRollThickness(2, Settings.KeyThickness),
    Canvas.Height, Settings.Palette.StrikeLine);

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

    StartPosition := StrikePosition +
      Round((Note.StartSeconds - TimeSeconds) * PixelsPerSecond);
    EndPosition := StrikePosition +
      Round((EndSeconds - TimeSeconds) * PixelsPerSecond);
    LeftPosition := Max(StrikePosition, Min(StartPosition, EndPosition));
    RightPosition := Max(StartPosition, EndPosition);
    if (RightPosition < 0) or (LeftPosition >= Canvas.Width) then
      Continue;

    GetKeyAxisBounds(Canvas.Height, Note.Key, LowestKey, HighestKey,
      Settings.KeyThickness, LaneTop, LaneBottom);
    NoteTop := LaneTop +
      Round((LaneBottom - LaneTop) * (1.0 - Thickness) / 2.0);
    NoteBottom := LaneBottom -
      Round((LaneBottom - LaneTop) * (1.0 - Thickness) / 2.0);
    BottomPosition := Max(NoteTop + 1, NoteBottom);
    Canvas.FillRectangle(LeftPosition, NoteTop,
      Max(LeftPosition + 1, RightPosition), BottomPosition,
      ResolvePianoRollTrackColor(Note.TrackIndex,
        Settings.TrackColorMode, Settings.SingleTrackColor,
        Settings.Palette));
  end;
end;

function CreateHorizontalPianoRollDisplay: IPianoRollDisplay;
begin
  Result := THorizontalPianoRollDisplay.Create;
end;

end.

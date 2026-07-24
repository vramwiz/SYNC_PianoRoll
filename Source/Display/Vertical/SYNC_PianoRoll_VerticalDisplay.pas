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
  SYNC_PianoRoll_RGBA;

type
  TVerticalPianoRollDisplay = class(TInterfacedObject, IPianoRollDisplay)
  private
    function GetTrackColor(TrackIndex: Integer): TPianoRollColor;
  public
    procedure Draw(var Canvas: TPianoRollCanvas;
      const Data: IPianoRollMusicData; TimeSeconds: Double;
      const Settings: TPianoRollDisplaySettings);
  end;

function TVerticalPianoRollDisplay.GetTrackColor(
  TrackIndex: Integer): TPianoRollColor;
begin
  case Abs(TrackIndex) mod 6 of
    0: Result := PianoRollColor(80, 210, 255, 255);
    1: Result := PianoRollColor(255, 120, 180, 255);
    2: Result := PianoRollColor(120, 235, 140, 255);
    3: Result := PianoRollColor(255, 205, 80, 255);
    4: Result := PianoRollColor(175, 130, 255, 255);
  else
    Result := PianoRollColor(255, 145, 75, 255);
  end;
end;

procedure TVerticalPianoRollDisplay.Draw(var Canvas: TPianoRollCanvas;
  const Data: IPianoRollMusicData; TimeSeconds: Double;
  const Settings: TPianoRollDisplaySettings);
var
  BottomPosition, EndPosition, I, KeyCount, KeyIndex: Integer;
  LaneLeft, LaneRight, NoteLeft, NoteRight: Integer;
  StartPosition, StrikePosition, TopPosition: Integer;
  EndSeconds, PixelsPerSecond, Thickness: Double;
  HighestKey, LowestKey: Integer;
  Note: TPianoRollNoteData;
begin
  if not Assigned(Data) or (Canvas.Width <= 0) or (Canvas.Height <= 0) then
    Exit;

  LowestKey := EnsureRange(Settings.LowestKey, 0, 127);
  HighestKey := EnsureRange(Settings.HighestKey, LowestKey, 127);
  KeyCount := HighestKey - LowestKey + 1;
  StrikePosition := EnsureRange(
    Round(Canvas.Height * Settings.StrikePosition), 0, Canvas.Height - 1);
  Canvas.FillRectangle(0, StrikePosition, Canvas.Width, StrikePosition + 2,
    PianoRollColor(255, 255, 255, 160));

  if Settings.DisplayTime <= 0 then
    Exit;
  PixelsPerSecond := Max(1, StrikePosition) / Settings.DisplayTime;
  Thickness := EnsureRange(Settings.NoteThickness, 0.05, 1.0);
  TimeSeconds := TimeSeconds - Settings.TimeShift;

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

    KeyIndex := Note.Key - LowestKey;
    LaneLeft := KeyIndex * Canvas.Width div KeyCount;
    LaneRight := (KeyIndex + 1) * Canvas.Width div KeyCount;
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

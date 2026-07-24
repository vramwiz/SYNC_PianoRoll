program SYNC_PianoRoll_MusicDataTests;

// 最小MIDIの直接解析と読み取り専用キャッシュの再生成を検証する。

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  RTTIPersistent in 'Source\Lib\SongReader\RTTIPersistent.pas',
  RTTIPersistentIni in 'Source\Lib\SongReader\RTTIPersistentIni.pas',
  SectionFileManager in 'Source\Lib\SongReader\SectionFileManager.pas',
  TextEncodingUtils in 'Source\Lib\SongReader\TextEncodingUtils.pas',
  SongAIUEO in 'Source\Lib\SongReader\SongAIUEO.pas',
  SongDataInfo in 'Source\Lib\SongReader\SongDataInfo.pas',
  SongDataNote in 'Source\Lib\SongReader\SongDataNote.pas',
  SongDataTempo in 'Source\Lib\SongReader\SongDataTempo.pas',
  SongDataTrack in 'Source\Lib\SongReader\SongDataTrack.pas',
  SongData in 'Source\Lib\SongReader\SongData.pas',
  SongReader in 'Source\Lib\SongReader\SongReader.pas',
  SongReaderSMF in 'Source\Lib\SongReader\SongReaderSMF.pas',
  SongReaderUST in 'Source\Lib\SongReader\SongReaderUST.pas',
  SongReaderVSQX in 'Source\Lib\SongReader\SongReaderVSQX.pas',
  SongReaderMusicXML in 'Source\Lib\SongReader\SongReaderMusicXML.pas',
  SongReaderMusicMSC in 'Source\Lib\SongReader\SongReaderMusicMSC.pas',
  SongReaderMusicMSCZ in 'Source\Lib\SongReader\SongReaderMusicMSCZ.pas',
  SongReaderManager in 'Source\Lib\SongReader\SongReaderManager.pas',
  SYNC_PianoRoll_MusicData in 'Source\Common\Data\SYNC_PianoRoll_MusicData.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure WriteMinimalMidi(const FileName: string; AppendPadding: Boolean);
const
  MidiData: array[0..34] of Byte = (
    $4D, $54, $68, $64, $00, $00, $00, $06,
    $00, $00, $00, $01, $01, $E0,
    $4D, $54, $72, $6B, $00, $00, $00, $0D,
    $00, $90, $3C, $64,
    $83, $60, $80, $3C, $00,
    $00, $FF, $2F, $00
  );
var
  Padding: Byte;
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(MidiData, SizeOf(MidiData));
    Padding := 0;
    if AppendPadding then
      Stream.WriteBuffer(Padding, SizeOf(Padding));
  finally
    Stream.Free;
  end;
end;

procedure RunTests(const FileName: string);
var
  Data1, Data2, Data3: IPianoRollMusicData;
  Note: TPianoRollNoteData;
begin
  Check(TryGetPianoRollMusicData(FileName, Data1),
    'minimal MIDI parse failed');
  Check(Data1.NoteCount = 1, 'note count mismatch');
  Note := Data1.Notes[0];
  Check(Note.Key = 60, 'note key mismatch');
  Check(Note.Velocity = 100, 'note velocity mismatch');
  Check(SameValue(Note.StartSeconds, 0.0), 'note start mismatch');
  Check(SameValue(Note.EndSeconds, 0.5), 'note end mismatch');

  Check(TryGetPianoRollMusicData(FileName, Data2),
    'cached MIDI lookup failed');
  Check(Pointer(Data1) = Pointer(Data2), 'cache snapshot was not reused');

  WriteMinimalMidi(FileName, True);
  Check(TryGetPianoRollMusicData(FileName, Data3),
    'MIDI reparse after size change failed');
  Check(Pointer(Data1) <> Pointer(Data3),
    'cache snapshot was not replaced after size change');
  Check(Data3.NoteCount = 1, 'reparsed note count mismatch');

  Check(not TryGetPianoRollMusicData(FileName + '.missing', Data3),
    'missing file must fail safely');
end;

var
  FileName: string;
begin
  FileName := TPath.Combine(TPath.GetTempPath,
    'SYNC_PianoRoll_' + TGUID.NewGuid.ToString + '.mid');
  InitializePianoRollMusicCache;
  try
    WriteMinimalMidi(FileName, False);
    RunTests(FileName);
    Writeln('PASS');
  finally
    FinalizePianoRollMusicCache;
    if TFile.Exists(FileName) then
      TFile.Delete(FileName);
  end;
end.

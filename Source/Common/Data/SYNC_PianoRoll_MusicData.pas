unit SYNC_PianoRoll_MusicData;

// 表示タイプに依存せず、元音楽ファイルの読み取り専用スナップショットを共有する。

interface

type
  TPianoRollNoteData = record
    StartSeconds: Double;
    EndSeconds: Double;
    Key: Integer;
    Velocity: Integer;
    TrackIndex: Integer;
    Lyric: string;
    LyricAIUEO: string;
  end;

  TPianoRollBeatData = record
    Seconds: Double;
    Index: Integer;
    TempoMicroseconds: Double;
  end;

  TPianoRollTrackData = record
    TrackIndex: Integer;
    Name: string;
  end;

  IPianoRollMusicData = interface
    ['{7E1136E8-9DA7-4F1B-BC52-D9B814DCE82A}']
    function GetFileName: string;
    function GetLengthSeconds: Double;
    function GetNoteCount: Integer;
    function GetNote(Index: Integer): TPianoRollNoteData;
    function GetBeatCount: Integer;
    function GetBeat(Index: Integer): TPianoRollBeatData;
    function GetTrackCount: Integer;
    function GetTrack(Index: Integer): TPianoRollTrackData;
    property FileName: string read GetFileName;
    property LengthSeconds: Double read GetLengthSeconds;
    property NoteCount: Integer read GetNoteCount;
    property Notes[Index: Integer]: TPianoRollNoteData read GetNote;
    property BeatCount: Integer read GetBeatCount;
    property Beats[Index: Integer]: TPianoRollBeatData read GetBeat;
    property TrackCount: Integer read GetTrackCount;
    property Tracks[Index: Integer]: TPianoRollTrackData read GetTrack;
  end;

procedure InitializePianoRollMusicCache;
procedure FinalizePianoRollMusicCache;
function TryGetPianoRollMusicData(const FileName: string;
  out Data: IPianoRollMusicData): Boolean;
function EnsurePianoRollMusicData(const FileName: string): Boolean;

implementation

uses
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils,
  SongData;

type
  TPianoRollMusicData = class(TInterfacedObject, IPianoRollMusicData)
  private
    FFileName: string;
    FLengthSeconds: Double;
    FNotes: TArray<TPianoRollNoteData>;
    FBeats: TArray<TPianoRollBeatData>;
    FTracks: TArray<TPianoRollTrackData>;
  public
    constructor Create(const FileName: string; Song: TSongData);
    function GetFileName: string;
    function GetLengthSeconds: Double;
    function GetNoteCount: Integer;
    function GetNote(Index: Integer): TPianoRollNoteData;
    function GetBeatCount: Integer;
    function GetBeat(Index: Integer): TPianoRollBeatData;
    function GetTrackCount: Integer;
    function GetTrack(Index: Integer): TPianoRollTrackData;
  end;

  TPianoRollMusicCacheEntry = class
  public
    FileAge: Integer;
    FileSize: Int64;
    IsValid: Boolean;
    Data: IPianoRollMusicData;
  end;

var
  MusicCache: TObjectDictionary<string, TPianoRollMusicCacheEntry>;
  MusicCacheLock: TCriticalSection;

constructor TPianoRollMusicData.Create(const FileName: string; Song: TSongData);
var
  I: Integer;
begin
  inherited Create;
  FFileName := FileName;
  FLengthSeconds := Song.LengthSec;

  SetLength(FNotes, Song.Notes.Count);
  for I := 0 to Song.Notes.Count - 1 do
  begin
    FNotes[I].StartSeconds := Song.Notes[I].StartSec;
    FNotes[I].EndSeconds := Song.Notes[I].EndSec;
    FNotes[I].Key := Song.Notes[I].Key;
    FNotes[I].Velocity := Song.Notes[I].Velocity;
    FNotes[I].TrackIndex := Song.Notes[I].TrackIndex;
    FNotes[I].Lyric := Song.Notes[I].Lyric;
    FNotes[I].LyricAIUEO := Song.Notes[I].LyricAIUEO;
  end;

  SetLength(FBeats, Song.Beats.Count);
  for I := 0 to Song.Beats.Count - 1 do
  begin
    FBeats[I].Seconds := Song.Beats[I].Sec;
    FBeats[I].Index := Song.Beats[I].Index;
    FBeats[I].TempoMicroseconds := Song.Beats[I].Tempo;
  end;

  SetLength(FTracks, Song.Tracks.Count);
  for I := 0 to Song.Tracks.Count - 1 do
  begin
    FTracks[I].TrackIndex := Song.Tracks[I].TrackIndex;
    FTracks[I].Name := Song.Tracks[I].TrackName;
  end;
end;

function TPianoRollMusicData.GetFileName: string;
begin
  Result := FFileName;
end;

function TPianoRollMusicData.GetLengthSeconds: Double;
begin
  Result := FLengthSeconds;
end;

function TPianoRollMusicData.GetNoteCount: Integer;
begin
  Result := Length(FNotes);
end;

function TPianoRollMusicData.GetNote(Index: Integer): TPianoRollNoteData;
begin
  Result := FNotes[Index];
end;

function TPianoRollMusicData.GetBeatCount: Integer;
begin
  Result := Length(FBeats);
end;

function TPianoRollMusicData.GetBeat(Index: Integer): TPianoRollBeatData;
begin
  Result := FBeats[Index];
end;

function TPianoRollMusicData.GetTrackCount: Integer;
begin
  Result := Length(FTracks);
end;

function TPianoRollMusicData.GetTrack(Index: Integer): TPianoRollTrackData;
begin
  Result := FTracks[Index];
end;

function ReadFileIdentity(const FileName: string; out Age: Integer;
  out Size: Int64): Boolean;
var
  Search: TSearchRec;
begin
  Age := -1;
  Size := -1;
  Result := FindFirst(FileName, faAnyFile, Search) = 0;
  if not Result then
    Exit;
  try
    if (Search.Attr and faDirectory) <> 0 then
    begin
      Result := False;
      Exit;
    end;
    Age := DateTimeToFileDate(Search.TimeStamp);
    Size := Search.Size;
  finally
    FindClose(Search);
  end;
end;

function LoadCacheEntry(const FileName: string; Age: Integer;
  Size: Int64): TPianoRollMusicCacheEntry;
var
  Song: TSongData;
begin
  Result := TPianoRollMusicCacheEntry.Create;
  Result.FileAge := Age;
  Result.FileSize := Size;
  Result.IsValid := False;
  Song := TSongData.Create;
  try
    try
      if not Song.LoadFromMusicFile(FileName) then
        Exit;
      Result.Data := TPianoRollMusicData.Create(FileName, Song);
      Result.IsValid := True;
    except
      // 壊れたファイルや未対応形式は無効キャッシュとして保持する。
      Result.Data := nil;
      Result.IsValid := False;
    end;
  finally
    Song.Free;
  end;
end;

procedure InitializePianoRollMusicCache;
begin
  if MusicCacheLock = nil then
    MusicCacheLock := TCriticalSection.Create;
  if MusicCache = nil then
    MusicCache :=
      TObjectDictionary<string, TPianoRollMusicCacheEntry>.Create([doOwnsValues]);
end;

procedure FinalizePianoRollMusicCache;
begin
  FreeAndNil(MusicCache);
  FreeAndNil(MusicCacheLock);
end;

function TryGetPianoRollMusicData(const FileName: string;
  out Data: IPianoRollMusicData): Boolean;
var
  Age: Integer;
  Entry: TPianoRollMusicCacheEntry;
  FullName, Key: string;
  Size: Int64;
begin
  Data := nil;
  Result := False;
  if Trim(FileName) = '' then
    Exit;

  try
    FullName := ExpandFileName(FileName);
    if not ReadFileIdentity(FullName, Age, Size) then
      Exit;
    Key := LowerCase(FullName);

    InitializePianoRollMusicCache;
    if (MusicCacheLock = nil) or (MusicCache = nil) then
      Exit;
    MusicCacheLock.Acquire;
    try
      if not MusicCache.TryGetValue(Key, Entry) or
        (Entry.FileAge <> Age) or (Entry.FileSize <> Size) then
      begin
        Entry := LoadCacheEntry(FullName, Age, Size);
        MusicCache.AddOrSetValue(Key, Entry);
      end;
      Result := Entry.IsValid and Assigned(Entry.Data);
      if Result then
        Data := Entry.Data;
    finally
      MusicCacheLock.Release;
    end;
  except
    // ファイルI/O、解析、キャッシュの例外をプラグイン境界へ出さない。
    Data := nil;
    Result := False;
  end;
end;

function EnsurePianoRollMusicData(const FileName: string): Boolean;
var
  Data: IPianoRollMusicData;
begin
  Result := TryGetPianoRollMusicData(FileName, Data);
end;

initialization
  MusicCache := nil;
  MusicCacheLock := nil;

finalization
  FinalizePianoRollMusicCache;

end.

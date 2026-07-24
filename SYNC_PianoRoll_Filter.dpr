library SYNC_PianoRoll_Filter;

// ピアノロールフィルターの AviUtl2 DLL 境界。

{$ALIGN 8}

uses
  Winapi.Windows,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_PianoRoll_FrameShared in 'Source\Common\Timeline\SYNC_PianoRoll_FrameShared.pas',
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
  SYNC_PianoRoll_ContextManager in 'Source\Common\Timeline\SYNC_PianoRoll_ContextManager.pas',
  SYNC_PianoRoll_MusicData in 'Source\Common\Data\SYNC_PianoRoll_MusicData.pas',
  SYNC_PianoRoll_PianoKeys in 'Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas',
  SYNC_PianoRoll_Colors in 'Source\Common\Color\SYNC_PianoRoll_Colors.pas',
  SYNC_PianoRoll_RGBA in 'Source\Common\Render\SYNC_PianoRoll_RGBA.pas',
  SYNC_PianoRoll_DisplayTypes in 'Source\Common\Layout\SYNC_PianoRoll_DisplayTypes.pas',
  SYNC_PianoRoll_VerticalDisplay in 'Source\Display\Vertical\SYNC_PianoRoll_VerticalDisplay.pas',
  SYNC_PianoRoll_Renderer in 'Source\Common\Render\SYNC_PianoRoll_Renderer.pas',
  SYNC_PianoRoll_FilterPlugin in 'Source\Plugin\Filter\SYNC_PianoRoll_FilterPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  InitializePianoRollFilter;
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizePianoRollFilter;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetPianoRollFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.

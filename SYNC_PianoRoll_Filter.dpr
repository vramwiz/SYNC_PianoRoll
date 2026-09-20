library SYNC_PianoRoll_Filter;

// 単体配置できる「ピアノロール」メディアオブジェクトのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  Winapi.Windows,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
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
  SYNC_PianoRoll_MusicData in 'Source\Common\Data\SYNC_PianoRoll_MusicData.pas',
  SYNC_PianoRoll_PianoKeys in 'Source\Common\Data\SYNC_PianoRoll_PianoKeys.pas',
  SYNC_PianoRoll_Colors in 'Source\Common\Color\SYNC_PianoRoll_Colors.pas',
  SYNC_PianoRoll_RGBA in 'Source\Common\Render\SYNC_PianoRoll_RGBA.pas',
  SYNC_PianoRoll_DisplayTypes in 'Source\Common\Layout\SYNC_PianoRoll_DisplayTypes.pas',
  SYNC_PianoRoll_PitchFollow in 'Source\Common\Layout\SYNC_PianoRoll_PitchFollow.pas',
  SYNC_PianoRoll_VerticalDisplay in 'Source\Display\Vertical\SYNC_PianoRoll_VerticalDisplay.pas',
  SYNC_PianoRoll_HorizontalDisplay in 'Source\Display\Horizontal\SYNC_PianoRoll_HorizontalDisplay.pas',
  SYNC_PianoRoll_Vertical3DDisplay in 'Source\Display\Vertical3D\SYNC_PianoRoll_Vertical3DDisplay.pas',
  SYNC_PianoRoll_Horizontal3DDisplay in 'Source\Display\Horizontal3D\SYNC_PianoRoll_Horizontal3DDisplay.pas',
  SYNC_PianoRoll_Circular3DDisplay in 'Source\Display\Circular3D\SYNC_PianoRoll_Circular3DDisplay.pas',
  SYNC_PianoRoll_Renderer in 'Source\Common\Render\SYNC_PianoRoll_Renderer.pas',
  SYNC_PianoRoll_MediaItems in 'Source\Plugin\Media\Registration\SYNC_PianoRoll_MediaItems.pas',
  SYNC_PianoRoll_SizePreset in 'Source\Plugin\Media\Editor\SYNC_PianoRoll_SizePreset.pas',
  SYNC_PianoRoll_MediaSettings in 'Source\Plugin\Media\Settings\SYNC_PianoRoll_MediaSettings.pas',
  SYNC_PianoRoll_MediaTime in 'Source\Plugin\Media\Timeline\SYNC_PianoRoll_MediaTime.pas',
  SYNC_PianoRoll_MediaDispatch in 'Source\Plugin\Media\Render\SYNC_PianoRoll_MediaDispatch.pas',
  SYNC_PianoRoll_MediaPlugin in 'Source\Plugin\Media\SYNC_PianoRoll_MediaPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  InitializePianoRollMedia;
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizePianoRollMedia;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetPianoRollMediaTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.

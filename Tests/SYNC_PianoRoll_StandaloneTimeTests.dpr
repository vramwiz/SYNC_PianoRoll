program SYNC_PianoRoll_StandaloneTimeTests;

// 単体フィルターへ渡されたローカル時刻の取得を検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_PianoRoll_FrameShared in 'Source\Common\Timeline\SYNC_PianoRoll_FrameShared.pas',
  SYNC_PianoRoll_ContextManager in 'Source\Common\Timeline\SYNC_PianoRoll_ContextManager.pas',
  SYNC_PianoRoll_Time in 'Source\Common\Timeline\SYNC_PianoRoll_Time.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  CurrentFileValue: UTF8String;
  CurrentObjectFrame: TOBJECT_LAYER_FRAME;
  CurrentObjectHandle: OBJECT_HANDLE;
  ObjectInfo: TOBJECT_INFO;
  SceneInfo: TSCENE_INFO;
  TimeSeconds: Double;
  Video: TFILTER_PROC_VIDEO;

function MockFindObject(Layer, Frame: Integer): OBJECT_HANDLE; cdecl;
begin
  if (Layer = CurrentObjectFrame.Layer) and
    (Frame = CurrentObjectFrame.StartFrame) then
    Result := CurrentObjectHandle
  else
    Result := nil;
end;

function MockGetObjectLayerFrame(
  Obj: OBJECT_HANDLE): TOBJECT_LAYER_FRAME; cdecl;
begin
  if Obj = CurrentObjectHandle then
    Result := CurrentObjectFrame
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function MockGetObjectItemValue(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
  Item: LPCWSTR): PAnsiChar; cdecl;
begin
  Result := nil;
  if (Obj = CurrentObjectHandle) and (string(Effect) = '動画ファイル') and
    (string(Item) = 'ファイル') then
    Result := PAnsiChar(CurrentFileValue);
end;

begin
  var EditSection: TEDIT_SECTION;

  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(EditSection, SizeOf(EditSection), 0);
  FillChar(SceneInfo, SizeOf(SceneInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  SceneInfo.Rate := 30;
  SceneInfo.Scale := 1;
  Video.Scene := @SceneInfo;
  CurrentObjectHandle := @ObjectInfo;
  EditSection.FindObject := MockFindObject;
  EditSection.GetObjectLayerFrame := MockGetObjectLayerFrame;
  EditSection.GetObjectItemValue := MockGetObjectItemValue;
  ObjectInfo.Flag := OBJECT_INFO_FLAG_FILTER_OBJECT;
  ObjectInfo.Time := 10.5;
  ObjectInfo.FrameS := 300;
  ObjectInfo.Frame := 15;
  Video.Object_ := @ObjectInfo;

  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'standalone time could not be resolved');
  Check(Abs(TimeSeconds - 0.5) < 0.000001,
    'object local frame time mismatch');

  // 配置開始位置やTime値が変わっても、自身のローカルフレームだけを使用する。
  ObjectInfo.Time := 0.5;
  ObjectInfo.FrameS := 600;
  ObjectInfo.Frame := 15;
  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'moved object time could not be resolved');
  Check(Abs(TimeSeconds - 0.5) < 0.000001,
    'object placement affected local time');

  // Input＋Filter方式では、メディアオブジェクトのローカル時刻ではなく
  // 入力設定の開始時間を含むInputフレームを音楽同期へ使用する。
  ObjectInfo.Flag := 0;
  ObjectInfo.ID := 100;
  ObjectInfo.EffectID := 200;
  ObjectInfo.Layer := 4;
  ObjectInfo.FrameS := 300;
  ObjectInfo.FrameE := 599;
  ObjectInfo.Frame := 0;
  ObjectInfo.Time := 0.0;
  CurrentObjectFrame.Layer := ObjectInfo.Layer;
  CurrentObjectFrame.StartFrame := ObjectInfo.FrameS;
  CurrentObjectFrame.EndFrame := ObjectInfo.FrameE;
  CurrentFileValue := UTF8String('1920_1080_3600_30_1.syncpianoroll');
  Video.Edit := @EditSection;
  PublishPianoRollFrame(81, 30, 1);
  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'input time could not be resolved');
  Check(Abs(TimeSeconds - 2.7) < 0.000001,
    'input start time was not applied');

  // 同一入力フレームが再取得されない再描画も、ローカルフレーム差分で補間する。
  ObjectInfo.Frame := 1;
  ObjectInfo.Time := 1 / 30;
  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'interpolated input time could not be resolved');
  Check(Abs(TimeSeconds - (82 / 30)) < 0.000001,
    'input time interpolation mismatch');

  // 専用Inputに載っていない一般メディアは、別Inputの共有値が残っていても採用しない。
  CurrentFileValue := UTF8String('ordinary-video.mp4');
  ObjectInfo.ID := 101;
  ObjectInfo.EffectID := 201;
  ObjectInfo.Frame := 15;
  ObjectInfo.Time := 0.5;
  Check(TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'ordinary media local time could not be resolved');
  Check(Abs(TimeSeconds - 0.5) < 0.000001,
    'ordinary media incorrectly used the shared input frame');

  Video.Object_ := nil;
  Check(not TryGetPianoRollTimeSeconds(@Video, TimeSeconds),
    'missing object was accepted');
  Writeln('PASS');
end.

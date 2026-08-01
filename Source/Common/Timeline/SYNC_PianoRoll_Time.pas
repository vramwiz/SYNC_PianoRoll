unit SYNC_PianoRoll_Time;

// 単体FilterまたはInput＋Filterの配置方式に応じた音楽同期時刻を取得する。

interface

uses
  AviUtl2FilterTypes;

function TryGetPianoRollTimeSeconds(Video: PFILTER_PROC_VIDEO;
  out TimeSeconds: Double): Boolean;

implementation

uses
  System.SysUtils,
  SYNC_PianoRoll_ContextManager,
  SYNC_PianoRoll_FrameShared;

function TryGetObjectFrameTimeSeconds(Video: PFILTER_PROC_VIDEO;
  out TimeSeconds: Double): Boolean;
begin
  Result := False;
  TimeSeconds := 0.0;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  // 非Input時は共有状態や配置開始位置を参照せず、現在のローカルフレームだけを時刻へ変換する。
  if (Video^.Scene <> nil) and (Video^.Scene^.Rate > 0) and
    (Video^.Scene^.Scale > 0) then
    TimeSeconds := Video^.Object_^.Frame * Video^.Scene^.Scale /
      Video^.Scene^.Rate
  else
    // SDK情報が不足するテスト環境等でも従来のローカル時刻を安全策として維持する。
    TimeSeconds := Video^.Object_^.Time;
  Result := True;
end;

function IsPianoRollInputObject(Video: PFILTER_PROC_VIDEO): Boolean;
const
  VIDEO_FILE_EFFECT = '動画ファイル';
  FILE_ITEM = 'ファイル';
  PIANO_ROLL_INPUT_EXTENSION = '.syncpianoroll';
var
  Edit: PEDIT_SECTION;
  FileName: string;
  FileValue: PAnsiChar;
  ObjectHandle: OBJECT_HANDLE;
  ObjectPosition: TOBJECT_LAYER_FRAME;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or
    ((Video^.Object_^.Flag and OBJECT_INFO_FLAG_FILTER_OBJECT) <> 0) then
    Exit;

  Edit := PEDIT_SECTION(Video^.Edit);
  if (Edit = nil) or not Assigned(Edit^.FindObject) or
    not Assigned(Edit^.GetObjectLayerFrame) or
    not Assigned(Edit^.GetObjectItemValue) then
    Exit;

  // 描画対象IDから編集オブジェクトのハンドルへ直接変換するAPIはないため、
  // 重複しないレイヤー上の開始位置で検索し、範囲一致で別オブジェクトを除外する。
  ObjectHandle := Edit^.FindObject(Video^.Object_^.Layer,
    Video^.Object_^.FrameS);
  if ObjectHandle = nil then
    Exit;
  ObjectPosition := Edit^.GetObjectLayerFrame(ObjectHandle);
  if (ObjectPosition.Layer <> Video^.Object_^.Layer) or
    (ObjectPosition.StartFrame <> Video^.Object_^.FrameS) or
    (ObjectPosition.EndFrame <> Video^.Object_^.FrameE) then
    Exit;

  // Inputプラグイン名はオブジェクトのエフェクト名に現れないため、
  // 標準の動画ファイル項目が専用拡張子を参照しているかで判定する。
  FileValue := Edit^.GetObjectItemValue(ObjectHandle, VIDEO_FILE_EFFECT,
    FILE_ITEM);
  if FileValue = nil then
    Exit;
  FileName := UTF8ToString(AnsiString(FileValue));
  Result := SameText(ExtractFileExt(FileName), PIANO_ROLL_INPUT_EXTENSION);
end;

function TryGetPianoRollTimeSeconds(Video: PFILTER_PROC_VIDEO;
  out TimeSeconds: Double): Boolean;
var
  UsesPianoRollInput: Boolean;
begin
  var EffectiveState: TSyncPianoRollFrameState;
  var SharedState: TSyncPianoRollFrameState;

  Result := False;
  TimeSeconds := 0.0;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  // フィルタオブジェクトには対応するInputがないため、自身のローカルフレームだけを使う。
  if (Video^.Object_^.Flag and OBJECT_INFO_FLAG_FILTER_OBJECT) <> 0 then
    Exit(TryGetObjectFrameTimeSeconds(Video, TimeSeconds));

  // 専用Inputに載ったメディアオブジェクトだけが共有フレームを使用する。
  // 同一シーンの一般メディアが別Inputの共有値を誤って採用しないよう、先に入力元を確認する。
  // 同一フレームの再描画でInputが再取得されない場合は、オブジェクト別基準から補間する。
  UsesPianoRollInput := IsPianoRollInputObject(Video);
  if UsesPianoRollInput and TryReadPianoRollFrame(SharedState) and
    ResolvePianoRollFrameState(Video, SharedState, EffectiveState) then
  begin
    TimeSeconds := EffectiveState.TimeSeconds;
    Exit(True);
  end;

  // 専用Inputに載っていなければ、共有メモリを使わず自身のフレームだけで動作する。
  if not UsesPianoRollInput then
    Exit(TryGetObjectFrameTimeSeconds(Video, TimeSeconds));

  // 専用Inputの共有値がまだ無い場合だけは、従来どおりSDKのローカル時刻で表示を継続する。
  TimeSeconds := Video^.Object_^.Time;
  Result := True;
end;

end.

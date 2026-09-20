unit SYNC_PianoRoll_MediaDispatch;

// 表示方式を選択し、2D画像出力とカメラ制御下の3D直接描画を明確に分ける。
interface
uses AviUtl2FilterTypes, SYNC_PianoRoll_MusicData, SYNC_PianoRoll_MediaSettings;
type TPianoRollRenderResult = (prrEmpty, prrImage, prrDirect);
procedure InitializePianoRollMediaDisplays;
procedure FinalizePianoRollMediaDisplays;
function DrawPianoRollMedia(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; Seconds: Double;
  const Settings: TPianoRollMediaSettings): TPianoRollRenderResult;
implementation
uses SYNC_PianoRoll_DisplayTypes, SYNC_PianoRoll_Renderer,
  SYNC_PianoRoll_VerticalDisplay, SYNC_PianoRoll_HorizontalDisplay,
  SYNC_PianoRoll_Vertical3DDisplay, SYNC_PianoRoll_Horizontal3DDisplay,
  SYNC_PianoRoll_Circular3DDisplay;
var VerticalDisplay, HorizontalDisplay: IPianoRollDisplay;
const
  // 初期メディアには画像リソースがない。DrawPolyの前提となる最小の素材を確保する。
  // 色付き頂点でも必要であり、寸法のローカル補完だけではホスト側の画像は生成されない。
  WHITE_PIXEL: TPIXEL_RGBA = (R: 255; G: 255; B: 255; A: 255);
procedure InitializePianoRollMediaDisplays;
begin
  VerticalDisplay := CreateVerticalPianoRollDisplay;
  HorizontalDisplay := CreateHorizontalPianoRollDisplay;
  InitializePianoRollRenderer;
end;
procedure FinalizePianoRollMediaDisplays;
begin
  FinalizePianoRollRenderer;
  VerticalDisplay := nil;
  HorizontalDisplay := nil;
end;
function DrawPianoRollMedia(Video: PFILTER_PROC_VIDEO;
  const Data: IPianoRollMusicData; Seconds: Double;
  const Settings: TPianoRollMediaSettings): TPianoRollRenderResult;
var Display: IPianoRollDisplay; Drawn: Boolean;
begin
  Result := prrEmpty;
  if Settings.Category <> Ord(pdcPiano) then Exit;
  if Settings.Dimension = Ord(prd3D) then
  begin
    if not Assigned(Video^.DrawPoly) or not Assigned(Video^.SetImageData) then
      Exit;
    Video^.SetImageData(@WHITE_PIXEL, 1, 1);
    // 深度判定はAviUtl2のカメラ制御が担当する。失敗を別方式の画像で覆い隠さない。
    case Settings.Style of
      Ord(pstType1):
        if Settings.Orientation = Ord(poHorizontal) then
          Drawn := DrawHorizontalPianoRoll3D(Video, Data, Seconds, Settings.Display)
        else
          Drawn := DrawVerticalPianoRoll3D(Video, Data, Seconds, Settings.Display);
      Ord(pstType2), Ord(pstType3):
        Drawn := DrawCircularPianoRoll3D(Video, Data, Seconds, Settings.Display,
          Settings.Orientation = Ord(poHorizontal), Settings.Style = Ord(pstType3));
    else
      Drawn := False;
    end;
    if Drawn then Result := prrDirect;
    Exit;
  end;
  if Settings.Dimension <> Ord(prd2D) then Exit;
  if Settings.Orientation = Ord(poHorizontal) then Display := HorizontalDisplay
  else Display := VerticalDisplay;
  if RenderPianoRoll(Video, Data, Seconds, Display, Settings.Display) then
    Result := prrImage;
end;
end.

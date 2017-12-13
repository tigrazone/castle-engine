{
  Copyright 2009-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Container for 2D controls able to render using OpenGL (TGLContainer). }
unit CastleGLContainer;

{$I castleconf.inc}

interface

uses Classes,
  CastleUIControls, CastleGLUtils, CastleRectangles, CastleColors,
  CastleImages;

type
  { Container for controls providing an OpenGL rendering.
    This class is internally used by TCastleWindowCustom and TCastleControlCustom.
    It is not useful from the outside, unless you want to implement
    your own container provider similar to TCastleWindowCustom / TCastleControlCustom. }
  TGLContainer = class abstract(TUIContainer)
  strict private
    FContext: TRenderContext;
    procedure RenderControlCore(const C: TUIControl;
      const ViewportRect: TRectangle;
      var SomeControlHasRenderStyle2D: boolean;
      const FilterRenderStyle: TRenderStyle);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Context: TRenderContext read FContext;
    procedure EventRender; override;
    procedure EventClose(const OpenWindowsCount: Cardinal); override;

    { Render a TUIControl (along with all it's children).
      Use this to render the UI control off-screen, see e.g.
      example render_3d_to_texture_and_use_as_quad.lpr.

      This doesn't only call @link(TUIControl.Render Control.Render).
      It also:

      @unorderedList(
        @item(Temporarily sets
          @link(TInputListener.Container Control.Container), if needed.)

        @item(Calls
          @link(TUIControl.GLContextOpen Control.GLContextOpen) and
          @link(TUIControl.GLContextClose Control.GLContextClose)
          around, if needed.)

        @item(Calls @link(TInputListener.Resize Control.Resize),
          required by some controls (like scene manager) to know viewport size.)

        @item(Calls @link(TUIControl.BeforeRender Control.BeforeRender),
          required by some controls (like scene manager)
          to prepare resources (like generated textures,
          important for mirrors for screenshots in batch mode).)
      )
    }
    procedure RenderControl(const Control: TUIControl;
      const ViewportRect: TRectangle);
  end;

{ Render control contents to an RGBA image, using off-screen rendering.
  The background behind the control is filled with BackgroundColor
  (which may be transparent, e.g. with alpha = 0).

  The rendering is done using off-screen FBO.
  Which means that you can request any size, you are @bold(not) limited
  to your current window / control size.

  Make sure that the control is nicely positioned to fill the ViewportRect.
  Usually you want to adjust control size and position,
  and disable UI scaling (set TUIControl.EnableUIScaling = @false
  if you use TUIContainer.UIScaling). }
function RenderControlToImage(const Container: TGLContainer;
  const Control: TUIControl;
  const ViewportRect: TRectangle;
  const BackgroundColor: TCastleColor): TRGBAlphaImage;

implementation

uses SysUtils,
  {$ifdef CASTLE_OBJFPC} CastleGL, {$else} GL, GLExt, {$endif}
  CastleVectors, CastleGLImages;

procedure ControlRenderBegin(const ViewportRect: TRectangle);
begin
  if GLFeatures.EnableFixedFunction then
  begin
    { Set state that is guaranteed for Render2D calls,
      but TUIControl.Render cannot change it carelessly. }
    {$ifndef OpenGLES}
    glDisable(GL_LIGHTING);
    glDisable(GL_FOG);
    {$endif}
    GLEnableTexture(CastleGLUtils.etNone);
  end;

  glDisable(GL_DEPTH_TEST);

  CastleGLUtils.glViewport(ViewportRect);
  OrthoProjection(FloatRectangle(0, 0, ViewportRect.Width, ViewportRect.Height));

  if GLFeatures.EnableFixedFunction then
  begin
    { Set OpenGL state that may be changed carelessly, and has some
      guaranteed value, for Render2d calls. }
    {$ifndef OpenGLES} glLoadIdentity; {$endif}
    {$warnings off}
    CastleGLUtils.WindowPos := Vector2Integer(0, 0);
    {$warnings on}
  end;
end;

{ TGLContainer --------------------------------------------------------------- }

constructor TGLContainer.Create(AOwner: TComponent);
begin
  inherited;
  FContext := TRenderContext.Create;
end;

destructor TGLContainer.Destroy;
begin
  if RenderContext = FContext then
    RenderContext := nil;
  FreeAndNil(FContext);
  inherited;
end;

procedure TGLContainer.RenderControlCore(const C: TUIControl;
  const ViewportRect: TRectangle;
  var SomeControlHasRenderStyle2D: boolean;
  const FilterRenderStyle: TRenderStyle);
var
  I: Integer;
begin
  if C.GetExists then
  begin
    { We check C.GLInitialized, because it may happen that a control
      did not receive GLContextOpen yet, in case we cause some rendering
      during TUIContainer.EventOpen (e.g. because some TUIControl.GLContextOpen
      calls Window.Screenshot, so everything is rendered
      before even the rest of controls received TUIControl.GLContextOpen).
      See castle_game_engine/tests/testcontainer.pas . }

    if C.GLInitialized then
    begin
      {$warnings off} // knowingly looking at deprecated RenderStyle, to keep it working
      if C.RenderStyle = FilterRenderStyle then
      {$warnings on}
      begin
        ControlRenderBegin(Rect);
        C.Render;
      end;
      {$warnings off} // knowingly looking at deprecated RenderStyle, to keep it working
      if C.RenderStyle = rs2D then
      {$warnings on}
        SomeControlHasRenderStyle2D := true;
    end;

    for I := 0 to C.ControlsCount - 1 do
      RenderControlCore(C.Controls[I], ViewportRect,
        SomeControlHasRenderStyle2D, FilterRenderStyle);

    {$warnings off} // knowingly looking at deprecated RenderStyle, to keep it working
    if C.GLInitialized and (C.RenderStyle = FilterRenderStyle) then
    {$warnings on}
    begin
      ControlRenderBegin(Rect);
      C.RenderOverChildren;
    end;
  end;
end;

procedure TGLContainer.EventRender;

  procedure RenderEverything(const FilterRenderStyle: TRenderStyle; out SomeControlHasRenderStyle2D: boolean);
  var
    I: Integer;
  begin
    SomeControlHasRenderStyle2D := false;

    { draw controls in "to" order, back to front }
    for I := 0 to Controls.Count - 1 do
      RenderControlCore(Controls[I], Rect, SomeControlHasRenderStyle2D, FilterRenderStyle);

    if TooltipVisible and (Focus.Count <> 0) then
    begin
      {$warnings off} // knowingly looking at deprecated RenderStyle, to keep it working
      if Focus.Last.TooltipStyle = FilterRenderStyle then
      {$warnings on}
      begin
        ControlRenderBegin(Rect);
        Focus.Last.TooltipRender;
      end;
      {$warnings off} // knowingly looking at deprecated RenderStyle, to keep it working
      if Focus.Last.TooltipStyle = rs2D then
      {$warnings on}
        SomeControlHasRenderStyle2D := true;
    end;

    {$warnings off} // knowingly looking at deprecated RenderStyle, to keep it working
    if RenderStyle = FilterRenderStyle then
    {$warnings on}
    begin
      ControlRenderBegin(Rect);
      if Assigned(OnRender) then OnRender(Self);
    end;
    {$warnings off} // knowingly looking at deprecated RenderStyle, to keep it working
    if RenderStyle = rs2D then
    {$warnings on}
      SomeControlHasRenderStyle2D := true;
  end;

var
  SomeControlHasRenderStyle2D, Dummy: boolean;
begin
  { Required to make DrawRectangle and TGLImageCore.Draw correct. }
  Viewport2DSize[0] := Width;
  Viewport2DSize[1] := Height;

  RenderEverything(rs3D, SomeControlHasRenderStyle2D);
  if SomeControlHasRenderStyle2D then
    RenderEverything(rs2D, Dummy);
end;

procedure TGLContainer.RenderControl(const Control: TUIControl;
  const ViewportRect: TRectangle);
var
  SomeControlHasRenderStyle2D, Dummy, NeedsContainerSet, NeedsGLOpen: boolean;
  OldContainer: TUIContainer;
begin
  NeedsContainerSet := Control.Container <> Self;
  NeedsGLOpen := not Control.GLInitialized;

  { TODO: calling the methods below is not recursive,
    it will not prepare the children correctly. }
  if NeedsContainerSet then
  begin
    OldContainer := Control.Container;
    Control.Container := Self;
  end;
  if NeedsGLOpen then
    Control.GLContextOpen;
  Control.Resize;
  Control.BeforeRender;

  { Required to make DrawRectangle and TGLImageCore.Draw correct. }
  Viewport2DSize[0] := ViewportRect.Width;
  Viewport2DSize[1] := ViewportRect.Height;

  SomeControlHasRenderStyle2D := false;
  RenderControlCore(Control, ViewportRect, SomeControlHasRenderStyle2D, rs3D);
  if SomeControlHasRenderStyle2D then
    RenderControlCore(Control, ViewportRect, Dummy, rs2D);

  { TODO: calling the methods below is not recursive,
    it will not unprepare the children correctly. }
  if NeedsContainerSet then
    Control.Container := OldContainer;
  if NeedsGLOpen then
    Control.GLContextClose;
end;

procedure TGLContainer.EventClose(const OpenWindowsCount: Cardinal);
begin
  inherited;
  if OpenWindowsCount = 1 then
  begin
    { recreate FContext instance, to reset every variable when context is closed }
    if RenderContext = FContext then
      RenderContext := nil;
    FreeAndNil(FContext);
    FContext := TRenderContext.Create;
  end;
end;

function RenderControlToImage(const Container: TGLContainer;
  const Control: TUIControl;
  const ViewportRect: TRectangle;
  const BackgroundColor: TCastleColor): TRGBAlphaImage;

  function CreateTargetTexture(const W, H: Integer): TGLTextureId;
  var
    InitialImage: TCastleImage;
  begin
    InitialImage := TRGBAlphaImage.Create(W, H);
    try
      InitialImage.URL := 'generated:/temporary-render-to-texture';
      InitialImage.Clear(Vector4Byte(255, 0, 255, 255));
      Result := LoadGLTexture(InitialImage,
        TextureFilter(minNearest, magNearest),
        Texture2DClampToEdge, nil, true);
    finally FreeAndNil(InitialImage) end;
  end;

var
  W, H: Integer;
  RenderToTexture: TGLRenderToTexture;
  TargetTexture: TGLTextureId;
begin
  W := ViewportRect.Width;
  H := ViewportRect.Height;
  RenderToTexture := TGLRenderToTexture.Create(W, H);
  try
    // RenderToTexture.Buffer := tbNone;
    // RenderToTexture.ColorBufferAlpha := true;

    RenderToTexture.Buffer := tbColor;
    TargetTexture := CreateTargetTexture(W, H);
    RenderToTexture.SetTexture(TargetTexture, GL_TEXTURE_2D);
    RenderToTexture.GLContextOpen;
    RenderToTexture.RenderBegin;

    { actually render }
    RenderContext.Clear([cbColor], BackgroundColor);
    Container.RenderControl(Control, ViewportRect);

    RenderToTexture.RenderEnd;

    Result := TRGBAlphaImage.Create(W, H);
    SaveTextureContents(Result, TargetTexture);

    RenderToTexture.GLContextClose;

    glFreeTexture(TargetTexture);
  finally FreeAndNil(RenderToTexture) end;
end;

end.

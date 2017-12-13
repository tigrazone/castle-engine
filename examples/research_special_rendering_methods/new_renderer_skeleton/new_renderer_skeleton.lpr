{
  Copyright 2017-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ A skeleton how you can test a new rendering target implementation
  (like Metal or Vulkan or Direct3D).

  In the future, Castle Game Engine should allow to "plug" a new renderer,
  such that the underlying renderer can be switched at runtime,
  and the public engine API stays the same.
  So all the engine classes (like TCastleScene, TCastleSceneManager, TCastleWindow,
  TCastleButton, TGLImage...) will work, regardless of the renderer.
  (And the name TGLImage will change to something more neutral,
  like TDrawImage, of course.)

  In the meantime, you can use this approach, which creates a descendant
  of TCastleSceneCore, to implement a new renderer.
}

uses SysUtils, TypInfo, Classes,
  CastleVectors, CastleCameras, X3DNodes, CastleSceneCore, CastleShapes,
  CastleTransform, CastleRenderingCamera, CastleProjection, CastleFrustum,
  CastleGeometryArrays;

var
  { Projection, as a trivial global variable. }
  ProjectionMatrix: TMatrix4;

{ Vulkan shape and scene ----------------------------------------------------- }

type
  { In this class you can store Vulkan-specific information that is per-shape.
    Inside the TCastleSceneVulkan implementation,
    you know that all your shapes are descendants of TVulkanShape. }
  TVulkanShape = class(TShape)
  end;

  { Scene that can be rendered using Vulkan. }
  TCastleSceneVulkan = class(TCastleSceneCore)
  protected
    function CreateShape(AGeometry: TAbstractGeometryNode;
      AState: TX3DGraphTraverseState; ParentInfo: PTraversingInfo): TShape; override;
  public
    procedure PrepareResources(const Options: TPrepareResourcesOptions;
      const ProgressStep: boolean; const Params: TPrepareParams); override;
    procedure LocalRender(const Frustum: TFrustum; const Params: TRenderParams); override;
  end;

function TCastleSceneVulkan.CreateShape(AGeometry: TAbstractGeometryNode;
  AState: TX3DGraphTraverseState; ParentInfo: PTraversingInfo): TShape;
begin
  Result := TVulkanShape.Create(Self, AGeometry, AState, ParentInfo);
end;

procedure TCastleSceneVulkan.PrepareResources(
  const Options: TPrepareResourcesOptions;
  const ProgressStep: boolean; const Params: TPrepareParams);
var
  SI: TShapeTreeIterator;
  Shape: TVulkanShape;
begin
  SI := TShapeTreeIterator.Create(Shapes, false, false);
  try
    while SI.GetNext do
    begin
      Shape := TVulkanShape(SI.Current);
      Writeln('Prepare to render shape: ', Shape.NiceName);

      { TODO: Load Shape data to GPU now.

        - E.g. load geometry data (Shape.GeometryArrays) to VBO.
          You should call Shape.GeometryArrays.FreeData afterwards,
          to not keep the data on CPU anymore.

        - E.g. load textures to GPU.

        - You should be prepared that some data may be already loaded.
          So all the loading should look like

            if not Shape.SomethingLoaded then
            begin
              Shape.SomethingLoaded := true;
              // load something here ...
            end;

        For a first renderer test you can also instead load on-demand
        from the Render implementation.
      }

    end;
  finally FreeAndNil(SI) end;
end;

procedure TCastleSceneVulkan.LocalRender(
  const Frustum: TFrustum; const Params: TRenderParams);

  function GetSceneModelView: TMatrix4;
  var
    CameraMatrix: PMatrix4;
  begin
    if RenderingCamera.RotationOnly then
      CameraMatrix := @RenderingCamera.RotationMatrix
    else
      CameraMatrix := @RenderingCamera.Matrix;

    if Params.RenderTransformIdentity then
      Result := CameraMatrix^
    else
      Result := CameraMatrix^ * Params.RenderTransform;
  end;

  function PrimitiveToStr(const Primitive: TGeometryPrimitive): string;
  begin
    Result := GetEnumName(TypeInfo(TGeometryPrimitive), Ord(Primitive));
  end;

var
  SceneModelView, ShapeModelView: TMatrix4;
  SI: TShapeTreeIterator;
  Shape: TVulkanShape;
  GeometryArrays: TGeometryArrays;
begin
  SceneModelView := GetSceneModelView;
  SI := TShapeTreeIterator.Create(Shapes, true, true);
  try
    while SI.GetNext do
    begin
      Shape := TVulkanShape(SI.Current);
      ShapeModelView := SceneModelView * Shape.State.Transform;
      Writeln('Rendering shape: ', Shape.NiceName);
      Writeln('Projection matrix:');
      Writeln(ProjectionMatrix.ToString('    '));
      Writeln('Modelview matrix: ');
      Writeln(ShapeModelView.ToString('    '));

      GeometryArrays := Shape.GeometryArrays(true);
      Writeln('Geometry:',
        ' Primitive: ', PrimitiveToStr(GeometryArrays.Primitive),
        ', HasIndexes: ',  GeometryArrays.HasIndexes,
        ', IndexesCount: ', GeometryArrays.IndexesCount,
        ', Count: ', GeometryArrays.Count);

      { TODO: Render Shape here.
        Load Shape.GeometryArrays to GPU,
        and pass parameters (like projection and modelview matrix) to shaders.
      }
    end;
  finally FreeAndNil(SI) end;
end;

{ Vulkan application and window ---------------------------------------------- }

type
  TVulkanApplication = class(TComponent)
  public
    // TODO: Process some inputs in TVulkanWindow, allow setting this to true.
    Quit: boolean;
  end;

  TVulkanWindow = class(TComponent)
  public
    Width, Height: Integer;
    procedure Open;
  end;

procedure TVulkanWindow.Open;
begin
  // TODO: create the Vulkan context, show the window
end;

{ initialization ------------------------------------------------------------- }

var
  Application: TVulkanApplication;
  Window: TVulkanWindow;
  Scene: TCastleSceneVulkan;
  Camera: TWalkCamera;
  Params: TRenderParams;
begin
  Application := TVulkanApplication.Create(nil);
  try
    Window := TVulkanWindow.Create(Application);
    Window.Width := 1024;
    Window.Height := 768;
    Window.Open;

    Camera := TWalkCamera.Create(Application);
    Camera.Init(
      Vector3(0, 0, 0), // position
      Vector3(0, 0, -1), // direction
      Vector3(0, 0, 1), // up
      Vector3(0, 0, 1), // gravity up
      2, // preferred height
      0.5 // collision radius
    );

    Scene := TCastleSceneVulkan.Create(Application);
    Scene.Load('../../3d_rendering_processing/data/bridge_final.x3dv');
    Scene.PrepareResources([], false, nil);

    { TODO: Creating TRenderParams with abstract methods (BaseLights).
      Ignore this temporarily, you don't need BaseLights to test your new renderer
      (BaseLights are only used for a configurable headlight, and for shining
      lights from one TCastleScene over another TCastleScene). }
    Params := TRenderParams.Create;

    while not Application.Quit do
    begin
      { TODO: Clear the screen contents (color, depth) now. }

      { Prepare projection, camera matrix, rendering parameters
        (this is done by TCastleSceneManager in normal circumstances). }
      ProjectionMatrix := PerspectiveProjectionMatrixDeg(
        60, Window.Width / Window.Height, 0.1, 1000);
      RenderingCamera.Matrix := Camera.Matrix;
      RenderingCamera.RotationMatrix := Camera.RotationMatrix;

      { In a real rendering, Scene.Render may be called more than once
        per frame, with different values of
        Params.Transparent and Params.ShadowVolumesReceivers,
        that filter various shapes.
        You can temporarily ignore this issue (until you will want to
        support blending (partial transparency) in your renderer). }

      // Render the Scene
      Scene.Render(RenderingCamera.Frustum, Params);

      { TODO: do something like Window.Flush or Window.SwapBuffers,
        to make sure GPU will execute the rendering commands ASAP. }

      { Testing: Wait for a key press, give user's a chance to press Ctrl + C :) }
      Readln;
    end;
  finally FreeAndNil(Application) end;
end.

{
  Copyright 2008-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ More involved version of animate_3d_model_by_code.lpr:
  constructs 3D model (VRML/X3D graph) by code and then animates it by code
  (showing a little more interesting animation, sin*cos displayed in 3D). }

{ $define LOG}

program animate_3d_model_by_code_2;

uses CastleVectors, X3DNodes, CastleWindow, CastleLog,
  CastleUtils, SysUtils, CastleGLUtils, CastleScene, CastleCameras,
  CastleFilesUtils, CastleQuaternions {$ifdef LOG} ,CastleLog {$endif}, CastleParameters,
  CastleStringUtils, CastleKeysMouse, CastleApplicationProperties;

var
  Window: TCastleWindow;
  Scene: TCastleScene;

const
  XCount = 15;
  YCount = 15;

var
  Transform: array [0 .. XCount - 1, 0 .. YCount - 1] of TTransformNode;

procedure Update(Container: TUIContainer);
var
  I, J: Integer;
  T: TVector3;
begin
  { We want to keep track of current time here (for calculating
    below). It's most natural to just use Scene.Time property for this.
    (Scene.Time is already incremented for us by SceneManager.) }

  for I := 0 to XCount - 1 do
    for J := 0 to YCount - 1 do
    begin
      T := Transform[I, J].Translation;
      T[2] := 2 *
        Sin(I / 2 + Scene.Time) *
        Cos(J / 2 + Scene.Time);
      Transform[I, J].Translation := T;
    end;
end;

function CreateVrmlGraph: TX3DRootNode;
var
  Shape: TShapeNode;
  Mat: TMaterialNode;
  I, J: Integer;
begin
  Result := TX3DRootNode.Create;

  Mat := TMaterialNode.Create;
  Mat.DiffuseColor := Vector3(1, 1, 0);

  Shape := TShapeNode.Create;
  Shape.Appearance := TAppearanceNode.Create;
  Shape.Appearance.Material := Mat;
  Shape.Geometry := TBoxNode.Create;

  for I := 0 to XCount - 1 do
    for J := 0 to YCount - 1 do
    begin
      Transform[I, J] := TTransformNode.Create;
      Transform[I, J].Translation := Vector3(I * 2, J * 2, 0);
      Transform[I, J].AddChildren(Shape);

      Result.AddChildren(Transform[I, J]);
    end;
end;

begin
  Window := TCastleWindow.Create(Application);

  Parameters.CheckHigh(0);
  ApplicationProperties.OnWarning.Add(@ApplicationProperties.WriteWarningOnConsole);

  { We use a lot of boxes, so make their rendering fastest. }
  DefaultTriangulationDivisions := 0;

  Scene := TCastleScene.Create(nil);
  try
    Scene.Load(CreateVrmlGraph, true);

    {$ifdef LOG}
    InitializeLog('1.0');
    Scene.LogChanges := true;
    {$endif}

    { add Scene to SceneManager }
    Window.SceneManager.MainScene := Scene;
    Window.SceneManager.Items.Add(Scene);

    { init SceneManager.Camera }
    Window.SceneManager.ExamineCamera.Init(Scene.BoundingBox, 0.1);
    { set more interesting view by default }
    Window.SceneManager.ExamineCamera.Rotations := QuatFromAxisAngle(
      Vector3(1, 1, 0).Normalize, Pi/4);

    Window.OnUpdate := @Update;
    Window.SetDemoOptions(K_F11, CharEscape, true);
    Window.OpenAndRun;
  finally Scene.Free end;
end.

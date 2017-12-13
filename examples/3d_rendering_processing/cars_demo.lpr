{
  Copyright 2010-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Demo of TCastleScene, scene manager and related functionality.
  Follow the relevant tutorial pages
  http://castle-engine.sourceforge.net/tutorial_load_3d.php
  http://castle-engine.sourceforge.net/tutorial_scene.php
}
program cars_demo;

uses SysUtils, CastleVectors, CastleTransform, CastleUIControls, CastleUtils,
  CastleFilesUtils, CastleWindow, CastleSceneCore, CastleScene,
  CastleKeysMouse, CastleBoxes, X3DNodes;

var
  Window: TCastleWindow;
  CarScene, RoadScene: TCastleScene;
  CarTransforms: array [1..20] of TCastleTransform;

procedure WindowUpdate(Container: TUIContainer);

  procedure UpdateCarTransform(const CarTransform: TCastleTransform);
  var
    T: TVector3;
  begin
    T := CarTransform.Translation;
    { Thanks to multiplying by SecondsPassed, it is a time-based operation,
      and will always move 40 units / per second along the -Z axis. }
    T := T + Vector3(0, 0, -40) * Container.Fps.UpdateSecondsPassed;
    { Wrap the Z position, to move in a loop }
    if T.Z < -70.0 then
      T.Z := 50.0;
    CarTransform.Translation := T;
  end;

var
  I: Integer;
begin
  for I := Low(CarTransforms) to High(CarTransforms) do
    UpdateCarTransform(CarTransforms[I]);
end;

procedure WindowPress(Container: TUIContainer; const Event: TInputPressRelease);
begin
  if Event.IsKey('c') then
    CarTransforms[1].Exists := not CarTransforms[1].Exists;

  { capture a screenshot }
  if Event.IsKey(K_F5) then
    Window.SaveScreen(FileNameAutoInc(ApplicationName + '_screen_%d.png'));
end;

function CreateBoxesScene: TCastleScene;
const
  WallHeight = 5;
var
  RoadBox: TBox3D;
  RootNode: TX3DRootNode;
  Appearance: TAppearanceNode;
  Material: TMaterialNode;
  Shape1, Shape2: TShapeNode;
  Box1, Box2: TBoxNode;
  Transform1, Transform2: TTransformNode;
begin
  { The created geometry will automatically adjust to the bounding box
    of the road 3D model. }
  RoadBox := RoadScene.BoundingBox;
  if RoadBox.IsEmpty then
    raise Exception.Create('Invalid road 3D model: empty bounding box');

  Material := TMaterialNode.Create;
  { Yellow (we could have also used YellowRGB constant from CastleColors unit) }
  Material.DiffuseColor := Vector3(1, 1, 0);
  Material.Transparency := 0.75;

  Appearance := TAppearanceNode.Create;
  Appearance.Material := Material;

  { Note: you could use TBoxNode.CreateWithTransform shortcut method
    to create Box1, Shape1, Transform1 in one instruction.
    But we show the longer version below, as it's easier to understand. }

  Box1 := TBoxNode.Create('box_1_geometry');
  Box1.Size := Vector3(0.5, WallHeight, RoadBox.Size.Z);

  Shape1 := TShapeNode.Create('box_1_shape');
  Shape1.Appearance := Appearance;
  Shape1.Geometry := Box1;

  Transform1 := TTransformNode.Create('box_1_transform');
  Transform1.Translation := Vector3(RoadBox.Min.X, WallHeight / 2, RoadBox.Center.Z);
  Transform1.AddChildren(Shape1);

  Box2 := TBoxNode.Create('box_2_geometry');
  Box2.Size := Vector3(0.5, WallHeight, RoadBox.Size.Z);

  Shape2 := TShapeNode.Create('box_2_shape');
  { Reuse the same Appearance node for another shape.
    This is perfectly allowed (the X3D is actually a graph, not a tree). }
  Shape2.Appearance := Appearance;
  Shape2.Geometry := Box2;

  Transform2 := TTransformNode.Create('box_2_transform');
  Transform2.Translation := Vector3(RoadBox.Max.X, WallHeight / 2, RoadBox.Center.Z);
  Transform2.AddChildren(Shape2);

  RootNode := TX3DRootNode.Create;
  RootNode.AddChildren(Transform1);
  RootNode.AddChildren(Transform2);

  Result := TCastleScene.Create(Application);
  Result.Load(RootNode, true);
end;

var
  I: Integer;
begin
  Window := TCastleWindow.Create(Application);

  CarScene := TCastleScene.Create(Application);
  CarScene.Load(ApplicationData('car.x3d'));
  CarScene.Spatial := [ssRendering, ssDynamicCollisions];
  CarScene.ProcessEvents := true;
  CarScene.PlayAnimation('wheels_turning', paForceLooping);

  for I := Low(CarTransforms) to High(CarTransforms) do
  begin
    CarTransforms[I] := TCastleTransform.Create(Application);
    CarTransforms[I].Translation := Vector3(
      -6 + Random(4) * 6, 0, RandomFloatRange(-70, 50));
    CarTransforms[I].Add(CarScene);
    Window.SceneManager.Items.Add(CarTransforms[I]);
  end;

  RoadScene := TCastleScene.Create(Application);
  RoadScene.Load(ApplicationData('road.x3d'));
  RoadScene.Spatial := [ssRendering, ssDynamicCollisions];
  RoadScene.ProcessEvents := true;

  Window.SceneManager.Items.Add(RoadScene);
  Window.SceneManager.MainScene := RoadScene;

  Window.SceneManager.Items.Add(CreateBoxesScene);

  Window.SceneManager.RequiredCamera.SetView(
    Vector3(-43.30, 27.23, -80.74),
    Vector3(  0.60, -0.36,   0.70),
    Vector3(  0.18,  0.92,   0.32)
  );
  // better camera for only a car:
  {Window.SceneManager.RequiredCamera.SetView(
    Vector3(-7.83,  6.15, -7.55),
    Vector3( 0.47, -0.30,  0.82),
    Vector3( 0.16,  0.95,  0.25)
  );}

  Window.OnUpdate := @WindowUpdate;
  Window.OnPress := @WindowPress;
  Window.Open;
  Application.Run;
end.

{
  Copyright 2007-2017 Michalis Kamburelis.

  This file is part of "The Rift".

  "The Rift" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "The Rift" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "The Rift"; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA

  ----------------------------------------------------------------------------
}

{ }
unit RiftCreatures;

{$I castleconf.inc}

interface

uses SysUtils, Classes, Generics.Collections,
  CastleUtils, CastleClassUtils, CastleScene,
  CastleVectors, CastleTransform, CastleFrustum, CastleApplicationProperties,
  CastleTimeUtils, X3DNodes, CastleColors, CastleDebugTransform,
  RiftWindow, RiftGame, RiftLoadable;

type
  TCreatureState = (csStand, csBored, csWalk);

const
  CreatureStateName: array [TCreatureState] of string =
  ( 'stand', 'bored', 'walk' );

type
  TCreatureAnimation = class
  public
    URL: string;
    Animation: TCastleScene; //< Created in TCreatureKind.Load
    Duration: Single;
  end;

  TCreatureKind = class(TLoadable)
  private
    FName: string;
    Animations: array [TCreatureState] of TCreatureAnimation;
    FReceiveShadowVolumes: boolean;
  protected
    procedure LoadInternal(const PrepareParams: TPrepareParams); override;
    procedure UnLoadInternal; override;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    { Internal creature name, must be simple (needs to be valid XML element
      name and VRML node name, for easy data reading). }
    property Name: string read FName;

    function LoadSteps: Cardinal; override;

    { Loads creature properties from DataConfig file.
      This is normally called by constructor, so you don't have to call it.
      However, it may be useful for debugging purposes to "reload index.xml"
      file, and then you should call this (and probably you should reload
      this creature kind, if it's already loaded; unless you know what
      you're doing :) ). }
    procedure LoadFromConfig;

    property ReceiveShadowVolumes: boolean read FReceiveShadowVolumes;
  end;

  TCreatureKindList = class({$ifdef CASTLE_OBJFPC}specialize{$endif} TObjectList<TCreatureKind>)
  public
    procedure Load(const PrepareParams: TPrepareParams);
    procedure UnLoad;
  end;

  TCreature = class(TCastleTransform)
  private
    FKind: TCreatureKind;
    FDebugTransform: TDebugTransform;
    FState: TCreatureState;
    CurrentChild: TCastleTransform;
    procedure SetState(const Value: TCreatureState);
  private
    { SetState actually only "schedules" actual state change at the nearest
      comfortable time (namely, when current animation will get to the state
      when it's sensible to make transition). }
    ScheduledTransitionBegin: boolean;
    ScheduledTransitionBeginNewState: TCreatureState;
    ScheduledTransitionBeginTime: TFloatTime;

    { Time of last change of state, from world time. }
    CurrentStateStartTime: TFloatTime;

    StandTimeToBeBored: TFloatTime;

    procedure RandomizeStandTimeToBeBored;
  public
    constructor Create(AKind: TCreatureKind); reintroduce;
    property Kind: TCreatureKind read FKind;
    property State: TCreatureState read FState write SetState;

    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;

    { This is called from @link(Update) when no state change is scheduled.
      Usually, you want to implement AI here, not directly in Update. }
    procedure UpdateNoStateChangeScheduled(const SecondsPassed: Single); virtual;
  end;

  TPlayer = class(TCreature)
  private
    { This is set and used only if csWalk }
    WantsToWalkPos, WantsToWalkDir: TVector3;
    FTargetVisualize: TTransformNode;
    FTargetVisualizeShape: TShapeNode;
  public
    constructor Create(AKind: TCreatureKind);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure LocationChanged;
    procedure WantsToWalk(const Value: TVector3);
  end;

var
  CreaturesKinds: TCreatureKindList;
  PlayerKind: TCreatureKind;

implementation

uses Math,
  CastleLog, CastleProgress, CastleGLUtils, CastleWindow,
  CastleUIControls, CastleGLBoxes, CastleSceneCore,
  RiftData, RiftVideoOptions;

{ TCreatureKind -------------------------------------------------------------- }

constructor TCreatureKind.Create(const AName: string);
var
  S: TCreatureState;
begin
  inherited Create;
  FName := AName;

  for S := Low(S) to High(S) do
    Animations[S] := TCreatureAnimation.Create;

  LoadFromConfig;
end;

destructor TCreatureKind.Destroy;
var
  S: TCreatureState;
begin
  for S := Low(S) to High(S) do
    FreeAndNil(Animations[S]);

  inherited;
end;

procedure TCreatureKind.LoadFromConfig;
const
  DefaultDuration = 0.5;
var
  S: TCreatureState;
  StatePath: string;
begin
  for S := Low(S) to High(S) do
  begin
    StatePath := 'creatures/' + Name + '/' + CreatureStateName[S] + '/';
    Animations[S].URL := DataConfig.GetURL(StatePath + 'url');
  end;
  FReceiveShadowVolumes := DataConfig.GetValue(
    'creatures/' + Name + '/receive_shadow_volumes', true);
end;

function TCreatureKind.LoadSteps: Cardinal;
begin
  Result := inherited LoadSteps + Ord(High(TCreatureState)) + 1;
end;

procedure TCreatureKind.LoadInternal(const PrepareParams: TPrepareParams);
var
  S: TCreatureState;
begin
  inherited;

  if DebugNoCreatures then
  begin
    Progress.Step(3);
    Exit;
  end;

  for S := Low(S) to High(S) do
  begin
    Animations[S].Animation := TCastleScene.Create(nil);
    { So not set Animation.ReceiveShadowVolumes := false,
      this would make incorrect rendering.
      Instead, we implement ReceiveShadowVolumes=false differently in this game.
      See TGameSceneManager.Render3D comments. }
    //Animations[S].Animation.ReceiveShadowVolumes := ReceiveShadowVolumes;
    Animations[S].Animation.Load(Animations[S].URL);
    Animations[S].Animation.PrepareResources(
      [prRender, prBoundingBox, prShadowVolume], false, PrepareParams);
    Animations[S].Duration := Animations[S].Animation.AnimationDuration('animation');
    Progress.Step;

    if Log then
      WritelnLog('Creature Animation', 'Loaded ' + Animations[S].URL);
  end;
end;

procedure TCreatureKind.UnLoadInternal;
var
  S: TCreatureState;
begin
  for S := Low(S) to High(S) do
    { this may be called from inherited destructor, so check for <> nil }
    if Animations[S] <> nil then
      FreeAndNil(Animations[S].Animation);

  inherited;
end;

{ TCreatureKindList -------------------------------------------------------- }

procedure TCreatureKindList.Load(const PrepareParams: TPrepareParams);
var
  I: Integer;
  ProgressCount: Cardinal;
  TimeBegin: TProcessTimerResult;
begin
  ProgressCount := 0;
  for I := 0 to Count - 1 do
    ProgressCount := ProgressCount + Items[I].LoadSteps;

  TimeBegin := ProcessTimer;

  Progress.Init(ProgressCount, 'Loading creatures');
  try
    for I := 0 to Count - 1 do
      Items[I].Load(PrepareParams);
  finally Progress.Fini end;

  WritelnLog('Creatures', Format('Creatures loading time: %f seconds',
    [ProcessTimerSeconds(ProcessTimer, TimeBegin)]));
end;

procedure TCreatureKindList.UnLoad;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I].UnLoad;
end;

{ TCreature ------------------------------------------------------------------ }

constructor TCreature.Create(AKind: TCreatureKind);
begin
  inherited Create(nil);

  { initialize state fields }
  FState := csStand;
  CurrentStateStartTime := WorldTime;

  FKind := AKind;

  RandomizeStandTimeToBeBored;

  FDebugTransform := TDebugTransform.Create(Self);
  FDebugTransform.Attach(Self);
end;

procedure TCreature.RandomizeStandTimeToBeBored;
begin
  StandTimeToBeBored := 10 + Random(5);
end;

procedure TCreature.SetState(const Value: TCreatureState);

  { Return nearest multiple of Multiple that is <= Value.
    You can assume that Value >= 0. }
  function RoundFloatDown(const Value, Multiple: TFloatTime): TFloatTime;
  begin
    Result := Floor(Value / Multiple) * Multiple;
  end;

begin
  if Value <> FState then
  begin
    { Note that using the "SetState sets scheduled state change"
      works OK if you will call SetState multiple times while waiting for
      comfortable time to actually change state: each SetState simply
      erases previously scheduled time, if any.

      So there will be no unnecessary waiting because of multiple "stacked"
      scheduled changes. }
    ScheduledTransitionBegin := true;
    ScheduledTransitionBeginNewState := Value;
    { calculate ScheduledTransitionBeginTime }
    if Kind.Animations[FState].Duration = 0 then
    begin
      { That's easy, just switch to new state already ! }
      ScheduledTransitionBeginTime := WorldTime;
    end else
    begin
      { So the current state is at WorldTime - CurrentStateStartTime time.
        When will it pass through it's "TimeEnd" point ? }
      ScheduledTransitionBeginTime := CurrentStateStartTime +
        RoundFloatDown(
          WorldTime - CurrentStateStartTime,
          Kind.Animations[FState].Duration);

      { Now at ScheduledTransitionBeginTime the animation was in starting
        position, and this is the time <= now. }
      ScheduledTransitionBeginTime := ScheduledTransitionBeginTime + Kind.Animations[FState].Duration;

      { Now at ScheduledTransitionBeginTime animation will end !
        This is good time to switch... unless it already occurred
        (which is possible
        1. because Animations[FState].Animation.TimeBackward
        are were currently in the "backward" step
        2. because of floating point errors inside RoundFloatDown...).
        So we correct it. If there were no floating point errors inside
        RoundFloatDown, loop below should execute at most once. }
      while ScheduledTransitionBeginTime < WorldTime do
        ScheduledTransitionBeginTime := ScheduledTransitionBeginTime + Kind.Animations[FState].Duration;
    end;
  end;
end;

procedure TCreature.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);

  function GetChild: TCastleTransform;
  var
    Scene: TCastleScene;
  begin
    Scene := Kind.Animations[FState].Animation;
    Result := Scene;
    Scene.ForceAnimationPose('animation',
      WorldTime - CurrentStateStartTime, paForceLooping);
  end;

  procedure UpdateChild;
  var
    NewChild: TCastleTransform;
  begin
    NewChild := GetChild;
    if CurrentChild <> NewChild then
    begin
      if CurrentChild <> nil then
        Remove(CurrentChild);
      CurrentChild := NewChild;
      if CurrentChild <> nil then
        Add(CurrentChild);
    end;
  end;

begin
  inherited;

  FDebugTransform.Exists := DebugRenderBoundingGeometry;

  if ScheduledTransitionBegin then
  begin
    if WorldTime > ScheduledTransitionBeginTime then
    begin
      ScheduledTransitionBegin := false;
      FState := ScheduledTransitionBeginNewState;
      CurrentStateStartTime := WorldTime;
    end;
  end else
    UpdateNoStateChangeScheduled(SecondsPassed);

  UpdateChild;
end;

procedure TCreature.UpdateNoStateChangeScheduled(const SecondsPassed: Single);
begin
  if State = csBored then
    State := csStand else
  if (State = csStand) and
     (WorldTime - CurrentStateStartTime > StandTimeToBeBored) then
  begin
    State := csBored;
    RandomizeStandTimeToBeBored;
  end;
end;

{ TPlayer -------------------------------------------------------------------- }

constructor TPlayer.Create(AKind: TCreatureKind);

  procedure CreateTargetVisualize;
  var
    Sphere: TSphereNode;
  begin
    Sphere := TSphereNode.Create;
    Sphere.Radius := 0.1;

    FTargetVisualizeShape := TShapeNode.Create;
    FTargetVisualizeShape.Material := TMaterialNode.Create;
    FTargetVisualizeShape.Material.DiffuseColor := RedRGB;
    FTargetVisualizeShape.Geometry := Sphere;

    FTargetVisualize := TTransformNode.Create;
    FTargetVisualize.AddChildren(FTargetVisualizeShape);
  end;

begin
  inherited;
  CreateTargetVisualize;
  FDebugTransform.WorldSpace.AddChildren(FTargetVisualize);
  FDebugTransform.ChangedScene;
end;

destructor TPlayer.Destroy;
begin
  inherited;
end;

procedure TPlayer.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  RotationAxis: TVector3;
  AngleToTarget: Single;

  procedure Rotate;
  var
    AngleRotate: Single;
  begin
    { first adjust direction }
    AngleRotate := SecondsPassed;
    if AngleToTarget < 0 then
      AngleRotate := Max(-AngleRotate, AngleToTarget) else
      AngleRotate := Min( AngleRotate, AngleToTarget);
    Direction := RotatePointAroundAxisRad(AngleRotate, Direction, RotationAxis);
  end;

  procedure Move;
  const
    MoveSpeed = 0.5;
  var
    MoveDirectionCurrent, MoveDirectionMax: TVector3;
    MoveDirectionCurrentScale: Single;
  begin
    { since Position <> WantsToWalkPos, we know that
      MoveDirectionMax is non-zero }
    MoveDirectionMax := WantsToWalkPos - Translation;
    MoveDirectionCurrentScale := MoveSpeed * SecondsPassed / MoveDirectionMax.Length;
    if MoveDirectionCurrentScale >= 1.0 then
    begin
      { This means that
          Translation + MoveDirectionMax * MoveDirectionCurrentScale
        would actually get us too far. So we instead just go to target and
        stop there. }
      Translation := WantsToWalkPos;
      State := csStand;
    end else
    begin
      MoveDirectionCurrent := MoveDirectionMax * MoveDirectionCurrentScale;
      Translation := Translation + MoveDirectionCurrent;
    end;
  end;

var
  IsTargetPos, IsTargetDir: boolean;
begin
  if (not ScheduledTransitionBegin) and (State = csWalk) then
  begin
    { Do walking. If walking ends (because target reached, or can't reach target),
      change to csStand. }

    { TODO: check collisions with the scene before changing Translation }

    IsTargetPos := TVector3.Equals(Translation, WantsToWalkPos);
    IsTargetDir := TVector3.Equals(Direction, WantsToWalkDir);

    if not IsTargetDir then
    begin
      { compare Direction and WantsToWalkDir with more tolerance }
      RotationAxis := TVector3.CrossProduct(Direction, WantsToWalkDir);
      AngleToTarget := RotationAngleRadBetweenVectors(Direction, WantsToWalkDir, RotationAxis);
      if Abs(AngleToTarget) < 0.01 then
        IsTargetDir := true;
    end;

    if IsTargetPos and IsTargetDir then
      State := csStand else
    if not IsTargetDir then
      Rotate else
      Move;
  end;

  FTargetVisualizeShape.Render := DebugRenderWantsToWalk and (State = csWalk);
  FTargetVisualize.Translation := WantsToWalkPos;

  { Update children 3D objects *after* updating our own transformation,
    this way they are always synchronized when displaying.
    Otherwise, the FTargetVisualize would have a bit of "shaking",
    because the TDebugTransform transformation would be updated with 1-frame delay. }
  inherited;
end;

procedure TPlayer.LocationChanged;
begin
  FState := csStand;
  ScheduledTransitionBegin := false;
  CurrentStateStartTime := WorldTime;
end;

procedure TPlayer.WantsToWalk(const Value: TVector3);
begin
  WantsToWalkPos := Value;
  WantsToWalkDir := (WantsToWalkPos - Direction).Normalize;
  { fix WantsToWalkDir, to avoid wild rotations.
    Without this, our avatar would wildly change up when walking to some
    higher/lower target. This is coupled with the fact that currently
    we accept any clicked position as walk target --- in a real game,
    it would be more limited where you can walk, and so this safeguard
    could be less critical. }
  if VectorsParallel(WantsToWalkDir, Up) then
    WantsToWalkDir := Direction else
    MakeVectorsOrthoOnTheirPlane(WantsToWalkDir, Up);
  State := csWalk;
end;

{ initialization / finalization ---------------------------------------------- }

procedure ContextClose;
begin
  FreeAndNil(CreaturesKinds);
end;

initialization
  CreaturesKinds := TCreatureKindList.Create(true);
  TCastleTransform.DefaultOrientation := otUpZDirectionX;

  PlayerKind := TCreatureKind.Create('player');
  CreaturesKinds.Add(PlayerKind);

  ApplicationProperties.OnGLContextClose.Add(@ContextClose);
end.

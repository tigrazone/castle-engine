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

{ Additional 3D objects derived from TCastleTransform (TAlive, T3DMoving...). }
unit Castle3D;

{$I castleconf.inc}

interface

uses SysUtils, Classes, Math, Generics.Collections, Kraft,
  CastleVectors, CastleFrustum, CastleBoxes, CastleClassUtils, CastleKeysMouse,
  CastleRectangles, CastleUtils, CastleTimeUtils,
  CastleSoundEngine, CastleSectors, CastleCameras, CastleTriangles,
  CastleTransform;

type
  T3D                         = CastleTransform.TCastleTransform deprecated 'use TCastleTransform from CastleTransform unit';
  T3DList                     = CastleTransform.TCastleTransform deprecated 'use TCastleTransform from CastleTransform unit';
  T3DCustomTranslated         = CastleTransform.TCastleTransform deprecated 'use TCastleTransform from CastleTransform unit';
  T3DTranslated               = CastleTransform.TCastleTransform deprecated 'use TCastleTransform from CastleTransform unit';
  T3DCustomTransform          = CastleTransform.TCastleTransform deprecated 'use TCastleTransform from CastleTransform unit';
  T3DTransform                = CastleTransform.TCastleTransform deprecated 'use TCastleTransform from CastleTransform unit';

  T3DOrient = class(CastleTransform.TCastleTransform)
  private
    FCamera: TWalkCamera;
  protected
    procedure ChangedTransform; override;
  public
    { Camera that is automatically synchronized with this 3D object. }
    property Camera: TWalkCamera read FCamera; deprecated 'instead of using this, better define your own TWalkCamera instance synchronized with this TCastleTransform';
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    constructor Create(AOwner: TComponent); override;
  end deprecated 'use TCastleTransform from CastleTransform unit';

  T3DListCore                 = CastleTransform.TCastleTransformList;
  T3DWorld                    = CastleTransform.TSceneManagerWorld;
  TCollisionDetails           = CastleTransform.TCollisionDetails;
  TRayCollision               = CastleTransform.TRayCollision;
  TRayCollisionNode           = CastleTransform.TRayCollisionNode;
  PRayCollisionNode           = CastleTransform.PRayCollisionNode;
  TRemoveType                 = CastleTransform.TRemoveType;
  TPrepareResourcesOption     = CastleTransform.TPrepareResourcesOption;
  TPrepareResourcesOptions    = CastleTransform.TPrepareResourcesOptions;
  TAbstractLightInstancesList = CastleTransform.TAbstractLightInstancesList;
  TRenderFromViewFunction     = CastleTransform.TRenderFromViewFunction;
  TRenderingPass              = CastleTransform.TRenderingPass;
  TRenderParams               = CastleTransform.TRenderParams;
  TBaseShadowVolumeRenderer   = CastleTransform.TBaseShadowVolumeRenderer;
  TVisibleChange              = CastleTransform.TVisibleChange;
  TVisibleChanges             = CastleTransform.TVisibleChanges;
  TRenderStatistics           = CastleTransform.TRenderStatistics;
  TRigidBody                  = CastleTransform.TRigidBody;
  TCollider                   = CastleTransform.TCollider;
  TSphereCollider             = CastleTransform.TSphereCollider;
  TBoxCollider                = CastleTransform.TBoxCollider;
  TPlaneCollider              = CastleTransform.TPlaneCollider;

  { 3D object moving and potentially pushing other 3D objects.
    Good for elevators, doors and such.

    Other 3D objects may be pushed, if @link(Pushes).
    There are two methods of pushing available, see @link(PushesEverythingInside).
    Only the 3D objects with @link(T3D.CollidesWithMoving) are ever pushed by
    this object (the rest of 3D world is treated as static, does not interact with
    elevators / doors or such).

    You can also stop/reverse the move to prevent some collisions
    from occuring at all. This way you can e.g. prevent the door
    from automatically closing, if someone/something blocks the way.
    You do this by overriding BeforeTimeIncrease.
    See TDoomLevelDoor.BeforeTimeIncrease in "The Castle" for example how to
    do this. }
  T3DMoving = class(TCastleTransform)
  private
    FPushes: boolean;
    FPushesEverythingInside: boolean;
    FAnimationTime: TFloatTime;
  protected
    { Local object time, always increasing, used to track animations. }
    property AnimationTime: TFloatTime read FAnimationTime;

    function GetTranslationFromTime(const AnAnimationTime: TFloatTime):
      TVector3; virtual; abstract;

    { Do something right before animation progresses.
      Called at the beginning of our @link(Update),
      @italic(right before) AnimationTime changes to NewAnimationTime.

      Useful for taking care of collision detection issues,
      as our assumption always is that "nothing collides". Which means
      that if you don't want your T3DMoving to collide
      with e.g. player or creatures or items, then you should
      prevent the collision @italic(before it happens).
      This is the place to do it. }
    procedure BeforeTimeIncrease(const NewAnimationTime: TFloatTime); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
  published
    { Are other 3D objects pushed when this object moves.
      Only the 3D objects with @link(TCastleTransform.CollidesWithMoving) are ever pushed by this object
      (the rest of 3D world is treated as static, does not interact with
      elevators / doors or such).

      Only relevant if GetCollides. Non-colliding objects never push others. }
    property Pushes: boolean read FPushes write FPushes default true;

    { If @link(Pushes) is @true, this determines how pushing actually works.
      There two methods:

      @orderedList(
        @item(PushesEverythingInside = @true: We move every
          3D object that is inside our bounding box and has CollidesWithMoving=@true.
          This is sensible if we can reasonably assume that things
          inside our box are standing. For example if this is
          a (vertical or horizontal) elevator, then creatures/items
          are usually standing/lying inside, and naturally move with
          the same speed (and direction) as the elevator.)

        @item(When PushesEverythingInside = @false: We check precise
          collision between 3D objects with CollidesWithMoving=@true
          and our triangle mesh.
          We use TCastleTransform.BoxCollision / TCastleTransform.SphereCollsion
          that can check collisions with TCastleScene precisely.)
      )

      Neither method is really perfect.

      PushesEverythingInside = @false seems like a more precise check,
      as it actually compares the triangle mesh, taking into account
      the interior of (this) moving 3D object. PushesEverythingInside = @true
      just approximates the moving 3D object by it's bounding box.

      On the other hand, PushesEverythingInside = @true makes the elevator
      more "sticky". With PushesEverythingInside = @false,
      when player hits the floor, it takes them some time to raise up.
      This creates a "bouncing camera" effect when the elevator goes up
      quickly: player constantly falls to the ground, tries to get up,
      but elevator moves up and player falls to it's ground again.
      When the elevator goes down, the player/creature constantly falls
      down on it because of gravity, which again causes artifacts
      as gravity may work significantly slower/faster than elavator moving speed.
      When the elevator is a horizontal moving platform, it will "slip"
      from under the player/creature, leaving the poor fella suddenly hanging
      in the air, and falling down because of gravity in the next second.

      In practice: PushesEverythingInside should be @true for small
      containers, when you can reasonably assume that things (creatures,
      player, items) stand inside, and when you intend to use it for transport
      of 3D stuff. For very large moving stuff, that possibly
      interacts with flying players/creatures in some creative way,
      PushesEverythingInside may be @false. }
    property PushesEverythingInside: boolean
      read FPushesEverythingInside write FPushesEverythingInside default true;
  end;

  { 3D moving with constant speed between 2 points.
    Moves with a constant speed from (0, 0, 0) to TranslationEnd.
    They are called @italic(begin position) and @italic(end position).

    This is a simplified, more comfortable descendant of T3DMoving.
    You get easy to use GoBeginPosition, GoEndPosition
    properties, you can easily set sounds by SoundGoBeginPosition and
    SoundGoEndPosition and such. }
  T3DLinearMoving = class(T3DMoving)
  private
    FEndPosition: boolean;
    FEndPositionStateChangeTime: Single;

    FSoundGoBeginPosition: TSoundType;
    FSoundGoEndPosition: TSoundType;
    FSoundGoBeginPositionLooping: boolean;
    FSoundGoEndPositionLooping: boolean;
    FSoundTracksCurrentPosition: boolean;

    UsedSound: TSound;
    procedure SoundRelease(Sender: TSound);
    function SoundPosition: TVector3;
    procedure PlaySound(SoundType: TSoundType; Looping: boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Is this object in @italic(end position), or going to it.
      If @false, then this object is in @italic(begin position)
      or going to it. See also CompletelyEndPosion and CompletelyBeginPosition.

      Initially this is @false, and EndPositionStateChangeTime is set such that
      we're sure that we're in CompletelyBeginPosion, }
    property EndPosition: boolean read FEndPosition;

    { Last time EndPosition changed. }
    property EndPositionStateChangeTime: Single read FEndPositionStateChangeTime;

    function CompletelyEndPosition: boolean;
    function CompletelyBeginPosition: boolean;

    { Start going to @italic(begin position), assuming that
      currently we're in @italic(end position) (i.e. CompletelyEndPosion). }
    procedure GoBeginPosition;

    { Start going to @italic(end position), assuming that
      currently we're in @italic(begin position) (i.e. CompletelyBeginPosion). }
    procedure GoEndPosition;

    { Stop going from @italic(end position) to @italic(begin position)
      and go back to @italic(end position). Call this only when currently
      EndPosition is @false and we were in the middle of going to
      @italic(begin position).

      As an example, this is what happens when door on DOOM level gets blocked.
      In the middle of closing (which ig going to @italic(begin position))
      it will realize that something blocks it, and open back
      (go back to @italic(end position)).  }
    procedure RevertGoEndPosition;

    { Just like RevertGoEndPosition, but this should be used in the middle
      of the move from @italic(begin position) to @italic(end position),
      to go back to @italic(begin position). }
    procedure RevertGoBeginPosition;

    { This goes to the @italic(other) position.
      Which means that if we're completely in @italic(end position)
      or in the middle of move to @italic(end position), this goes
      back to @italic(begin position). And if we're in @italic(begin position),
      this goes back to @italic(end position). }
    procedure GoOtherPosition;

    property SoundGoBeginPosition: TSoundType
      read FSoundGoBeginPosition write FSoundGoBeginPosition;
    property SoundGoEndPosition: TSoundType
      read FSoundGoEndPosition write FSoundGoEndPosition;

    property SoundGoBeginPositionLooping: boolean
      read FSoundGoBeginPositionLooping write FSoundGoBeginPositionLooping
      default false;
    property SoundGoEndPositionLooping: boolean
      read FSoundGoEndPositionLooping write FSoundGoEndPositionLooping
      default false;

    { If @true then the sound (set by SoundGoBeginPosition or
      SoundGoEndPosition) 3D position changes as the 3D position of the object
      changes.

      Otherwise (default) sound is initially made at initial
      3D position of this object, and then the sound position doesn't change
      (even if the position of the object changes). }
    property SoundTracksCurrentPosition: boolean
      read FSoundTracksCurrentPosition write FSoundTracksCurrentPosition
      default false;
  public
    MoveTime: Single;
    TranslationEnd: TVector3;

    function GetTranslationFromTime(const AnAnimationTime: TFloatTime):
      TVector3; override;

    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
  end;

  { Alive, oriented 3D object. Basis for players, creatures and everything
    else that has some position, direction and that can be killed.

    Note that the TAlive doesn't remove dead objects, doesn't make any
    dead animations or such. TAlive class merely keeps track of
    @link(Life), @link(Dead) and such properties,
    and allows you to call @link(Hurt) doing eventual knockback.
    If your own code doesn't call @link(Hurt),
    or even doesn't look at @link(Life) value, then they have no implication
    for given 3D object, so it may be indestructible just like other 3D objects. }
  TAlive = class(TCastleTransform)
  private
    FLifeTime: Single;
    FDieTime: Single;
    FLife: Single;
    FMaxLife: Single;
    { FKnockbackDistance <= 0 means "no knockback currently" }
    FKnockbackDistance: Single;
    FLastHurtDirection: TVector3;
    { Same as LastHurtDirection but (for things with Gravity) flattened
      to be orthogonal to World.Gravity. This prevents from "pushing" creatures
      into the floor by hitting them in downward direction, which is often
      too easy for non-flying creatures that have Sphere with Middle point high. }
    FLastHurtDirectionGround: TVector3;
    FKnockBackSpeed: Single;
  protected
    procedure SetLife(const Value: Single); virtual;
    procedure CancelKnockback;
  public
    const
      DefaultKnockBackSpeed = 1.0;

    constructor Create(AOwner: TComponent); override;

    { Shortcut for checking Life <= 0. }
    function Dead: boolean;

    { Hurt given creature, decreasing it's life by LifeLoss,
      setting last attack direction (used by knockback and some other effects),
      optionally doing a knockback.
      If all you want to do is to decrease Life, you can also just set @link(Life)
      property. Unless your code depends on LastHurtDirection being always updated
      (only TCreature in CastleCreatures unit depends on it now).

      HurtDirection should be a normalized vector indicating direction
      in which the attack came.

      AKnockbackDistance, if non-zero, indicates to push creature by given
      length in the direction given by HurtDirection.
      Ignored if HurtDirection is zero.

      Attacker is the other alive creature that caused this damage. It may be @nil
      if no other TAlive is directly responsible for this damage. This may
      be useful for various purposes, for example the victim may become aware
      of attacker presence when it's attacked. }
    procedure Hurt(const LifeLoss: Single;
      const HurtDirection: TVector3;
      const AKnockbackDistance: Single; const Attacker: TAlive); virtual;

    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;

    { Direction from where the attack came.
      Zero if there was no specific direction of last attack,
      otherwise a normalized (length 1) vector. }
    property LastHurtDirection: TVector3 read FLastHurtDirection;

    property LifeTime: Single read FLifeTime;

    { Time of death, only valid if @link(Dead), taken from LifeTime. }
    property DieTime: Single read FDieTime;
  published
    { Current Life. We're dead when this is <= 0. }
    property Life: Single read FLife write SetLife;

    { Maximum amount of life. Used as default value for Life when sensible.
      Can be also used for information (to display on player HUDs and such).

      It's not really a limit, that is you can set Life
      to something larger than MaxLife if you want. It's normal in some games,
      where you can get some "magic life boost" that makes your health temporarily
      larger than normal. Whether it's sensible in your game (and whether your
      HUD will display it sensibly) is up to you. }
    property MaxLife: Single read FMaxLife write FMaxLife;

    { Scales how far the knockback effect pushes this creature/player. }
    property KnockBackSpeed: Single read FKnockBackSpeed write FKnockBackSpeed
      default DefaultKnockBackSpeed;
  end;

  T3DAlive = TAlive deprecated 'use TAlive';

  T3DExistsEvent = function(const Item: T3D): boolean of object;

const
  MaxSingle = Math.MaxSingle;

  { Default values common to TPlayer and TCreature classes.

    Note that FallMinHeightToSound is usually better to be larger for player,
    to avoid making "fall" sound when player merely jumps or walks down a steep
    hill. No such need for creature.

    @groupBegin }
  DefaultFallMinHeightToDamage = 5.0;
  DefaultFallDamageScaleMin = 0.8;
  DefaultFallDamageScaleMax = 1.2;
  DefaultCreatureFallMinHeightToSound = 1.0;
  DefaultPlayerFallMinHeightToSound = 4.0;
  DefaultCreatureFallSoundName = 'creature_fall';
  DefaultPlayerFallSoundName = 'player_fall';
  { @groupEnd }

  vcVisibleGeometry    = CastleTransform.vcVisibleGeometry;
  vcVisibleNonGeometry = CastleTransform.vcVisibleNonGeometry;
  prShadowVolume       = CastleTransform.prShadowVolume;
  prSpatial            = CastleTransform.prSpatial;
  prScreenEffects      = CastleTransform.prScreenEffects;
  prRender             = CastleTransform.prRender;
  prBackground         = CastleTransform.prBackground;
  prBoundingBox        = CastleTransform.prBoundingBox;
  rtNone               = CastleTransform.rtNone;
  rtRemove             = CastleTransform.rtRemove;
  rtRemoveAndFree      = CastleTransform.rtRemoveAndFree;
  otUpYDirectionMinusZ = CastleTransform.otUpYDirectionMinusZ;
  otUpZDirectionMinusY = CastleTransform.otUpZDirectionMinusY;
  otUpZDirectionX      = CastleTransform.otUpZDirectionX;

var
  { Creatures, items and possibly other 3D stuff may look at these variables
    to display additional features of 3D objects, helpful to debug collisions,
    AI and other things.
    @groupBegin }
  RenderDebug3D: boolean = false
    deprecated 'use Player.RenderDebug, TCreature.RenderDebug, TItemOnWorld.RenderDebug';
  RenderDebugCaptions: boolean = false
    deprecated 'use TCreature.RenderDebug';
  { @groupEnd }

  { Log shadow volume information.

    Meaningful only if you initialized log (see CastleLog unit) by InitializeLog first. }
  LogShadowVolumes: boolean = false;

implementation

uses CastleLog;

{ T3DOrient ------------------------------------------------------------------ }

constructor T3DOrient.Create(AOwner: TComponent);
begin
  inherited;
  FCamera := TWalkCamera.Create(Self);
end;

procedure T3DOrient.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  P, D, U: TVector3;
begin
  inherited;
  // synchronize Position, Direction, Up *from* Camera
  {$warnings off} // knowingly using deprecated
  Camera.GetView(P, D, U);
  {$warnings on}
  SetView(P, D, U);
end;

procedure T3DOrient.ChangedTransform;
var
  P, D, U: TVector3;
begin
  inherited;
  // synchronize Position, Direction, Up *to* Camera
  GetView(P, D, U);
  {$warnings off} // knowingly using deprecated
  Camera.SetView(P, D, U);
  {$warnings on}
end;

{ T3DMoving --------------------------------------------------------- }

{ TODO: this browses World list, doesn't take into acount CollidesWithMoving items
  that may be inside a sublist. }

constructor T3DMoving.Create(AOwner: TComponent);
begin
  inherited;
  FPushes := true;
  FPushesEverythingInside := true;
  FAnimationTime := 0;
end;

{ Note: When pushing the creature/player/item, right now
  we don't check whether the creature/player/item will not be
  pushed into collision with something else.

  For now, design your level to minimize the chance that it will ever happen.
  Although in theory you cannot design your level to guarantee
  that it will never happen (because e.g. a creature may be pushed
  into collision with other creature, and since creatures move
  on their own they can arrange themselves (in theory) in all manners of
  funny configurations...). But in practice it's not so difficult,
  just make sure that there is enough space on the way of move.
}

procedure T3DMoving.BeforeTimeIncrease(
  const NewAnimationTime: TFloatTime);

  function BoundingBoxAssumeTranslation(
    const AssumeTranslation: TVector3): TBox3D;
  begin
    if GetCollides then
      Result := (inherited BoundingBox).Translate(AssumeTranslation) else
      Result := TBox3D.Empty;
  end;

  function SphereCollisionAssumeTranslation(
    const AssumeTranslation: TVector3;
    const Pos: TVector3; const Radius: Single;
    const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean;
  begin
    Result := GetCollides;
    if Result then
    begin
      { We use the same trick as in TCastleTransform.MoveCollision to
        use "inherited SphereCollsion" with Translation. }

      Result := inherited SphereCollision(
        Pos - AssumeTranslation, Radius, TrianglesToIgnoreFunc);
    end;
  end;

  function BoxCollisionAssumeTranslation(
    const AssumeTranslation: TVector3;
    const Box: TBox3D;
    const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean;
  begin
    Result := GetCollides;
    if Result then
    begin
      { We use the same trick as in TCastleTransform.MoveCollision to
        use "inherited BoxCollision" with Translation. }

      Result := inherited BoxCollision(
        Box.AntiTranslate(AssumeTranslation), TrianglesToIgnoreFunc);
    end;
  end;

var
  CurrentBox, NewBox, Box: TBox3D;
  I: Integer;
  MoveTranslation: TVector3;
  CurrentTranslation, NewTranslation: TVector3;
  SphereRadius: Single;
  Item: TCastleTransform;
begin
  if GetCollides and Pushes then
  begin
    CurrentTranslation := GetTranslationFromTime(AnimationTime);
    NewTranslation := GetTranslationFromTime(NewAnimationTime);

    { It often happens that T3DMoving doesn't move at all,
      and then MoveTranslation doesn't change at all
      (even when compared precisely, without usual epsilon used to compare
      floats). So the check below may be worth the time, we expect
      it will avoid doing actual work. }

    if not TVector3.PerfectlyEquals(CurrentTranslation, NewTranslation) then
    begin
      MoveTranslation := NewTranslation - CurrentTranslation;

      { TODO: it may be sensible to add a pushing method when we compare
        other object's bounding box (never a sphere, and be sure to use
        the "tall" box for player, including it's legs) with octree
        (that is, using inherited BoxCollision).
        This can have the advantages of both PushesEverythingInside=true
        (reacts more sticky, more eager to move colliding stuff with
        the same speed as elevator)
        and PushesEverythingInside=false (takes into account triangle mesh,
        not just our bounding volume). }

      if PushesEverythingInside then
      begin
        CurrentBox := BoundingBox;
        NewBox := BoundingBoxAssumeTranslation(NewTranslation);
        for I := 0 to World.Count - 1 do
        begin
          Item := World[I];
          if (Item is TCastleTransform) and Item.CollidesWithMoving then
          begin
            { This case doesn't really use Item.Sphere. But it's not really
              terribly important design decision, we may use Item.Sphere
              one day here. It's most comfortable to just use
              here Item.BoundingBox, as we perform collisions with our box. }
            Box := Item.BoundingBox;
            if Box.Collision(NewBox) or
               Box.Collision(CurrentBox) then
              TCastleTransform(Item).Translate(MoveTranslation);
          end;
        end;
      end else
      begin
        for I := 0 to World.Count - 1 do
        begin
          Item := World[I];
          if (Item is TCastleTransform) and Item.CollidesWithMoving then
            if Item.Sphere(SphereRadius) then
            begin
              if SphereCollisionAssumeTranslation(NewTranslation,
                Item.Middle, SphereRadius,
                {$ifdef CASTLE_OBJFPC}@{$endif} World.CollisionIgnoreItem) then
                TCastleTransform(Item).Translate(MoveTranslation);
            end else
            begin
              if BoxCollisionAssumeTranslation(NewTranslation,
                Item.BoundingBox,
                {$ifdef CASTLE_OBJFPC}@{$endif} World.CollisionIgnoreItem) then
                TCastleTransform(Item).Translate(MoveTranslation);
            end;
        end;
      end;
    end;
  end;
end;

procedure T3DMoving.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  NewAnimationTime: TFloatTime;
begin
  inherited;

  NewAnimationTime := AnimationTime + SecondsPassed;
  BeforeTimeIncrease(NewAnimationTime);
  FAnimationTime := NewAnimationTime;

  Translation := GetTranslationFromTime(AnimationTime);
end;

{ T3DLinearMoving --------------------------------------------------- }

constructor T3DLinearMoving.Create(AOwner: TComponent);
begin
  inherited;

  FSoundGoEndPosition := stNone;
  FSoundGoBeginPosition := stNone;

  FEndPosition := false;

  { We set FEndPositionStateChangeTime to a past time, to be sure
    that we don't treat the door as "closing right now". }
  FEndPositionStateChangeTime := -1000.0; { TODO: should be implemented better... }

  UsedSound := nil;
end;

destructor T3DLinearMoving.Destroy;
begin
  { Otherwise, if you exit from the game while some sound was played,
    and the sound was e.g. looping (like the elevator on "Tower" level),
    the sound will never get stopped. }
  if UsedSound <> nil then
    UsedSound.Release;

  inherited;
end;

procedure T3DLinearMoving.SoundRelease(Sender: TSound);
begin
  Assert(Sender = UsedSound);
  UsedSound := nil;
end;

function T3DLinearMoving.SoundPosition: TVector3;
begin
  Result := BoundingBox.Center;
end;

procedure T3DLinearMoving.PlaySound(SoundType: TSoundType;
  Looping: boolean);
begin
  { The object can play only one sound (going to begin or end position)
    at a time. }
  if UsedSound <> nil then
    UsedSound.Release;
  UsedSound := SoundEngine.Sound3d(SoundType, SoundPosition, Looping);

  if UsedSound <> nil then
    UsedSound.OnRelease := {$ifdef CASTLE_OBJFPC}@{$endif} SoundRelease;
end;

procedure T3DLinearMoving.GoEndPosition;
begin
  FEndPosition := true;
  FEndPositionStateChangeTime := AnimationTime;
  PlaySound(SoundGoEndPosition, SoundGoEndPositionLooping);
end;

procedure T3DLinearMoving.GoBeginPosition;
begin
  FEndPosition := false;
  FEndPositionStateChangeTime := AnimationTime;
  PlaySound(SoundGoBeginPosition, SoundGoBeginPositionLooping);
end;

procedure T3DLinearMoving.RevertGoEndPosition;
begin
  FEndPosition := true;
  FEndPositionStateChangeTime := { AnimationTime -
    (MoveTime - (AnimationTime - EndPositionStateChangeTime)) }
    { simplified : }
    2 * AnimationTime - MoveTime - EndPositionStateChangeTime;
  PlaySound(SoundGoEndPosition, SoundGoEndPositionLooping);
end;

procedure T3DLinearMoving.RevertGoBeginPosition;
begin
  FEndPosition := false;
  FEndPositionStateChangeTime := { AnimationTime -
    (MoveTime - (AnimationTime - EndPositionStateChangeTime)) }
    { simplified : }
    2 * AnimationTime - MoveTime - EndPositionStateChangeTime;
  PlaySound(SoundGoEndPosition, SoundGoBeginPositionLooping);
end;

procedure T3DLinearMoving.GoOtherPosition;
begin
  if CompletelyEndPosition then
    GoBeginPosition else
  if CompletelyBeginPosition then
    GoEndPosition else
  begin
    if EndPosition then
      RevertGoBeginPosition else
      RevertGoEndPosition;
  end;
end;

function T3DLinearMoving.GetTranslationFromTime(
  const AnAnimationTime: TFloatTime): TVector3;
begin
  if not EndPosition then
  begin
    if AnAnimationTime - EndPositionStateChangeTime > MoveTime then
      { Completely closed. }
      Result := TVector3.Zero else
      { During closing. }
      Result := TranslationEnd *
        (1 - (AnAnimationTime - EndPositionStateChangeTime) / MoveTime);
  end else
  begin
    if AnAnimationTime - EndPositionStateChangeTime > MoveTime then
      { Completely open. }
      Result := TranslationEnd else
      { During opening. }
      Result := TranslationEnd *
        ((AnAnimationTime - EndPositionStateChangeTime) / MoveTime);
  end;
end;

function T3DLinearMoving.CompletelyEndPosition: boolean;
begin
  Result := EndPosition and
    (AnimationTime - EndPositionStateChangeTime > MoveTime);
end;

function T3DLinearMoving.CompletelyBeginPosition: boolean;
begin
  Result := (not EndPosition) and
    (AnimationTime - EndPositionStateChangeTime > MoveTime);
end;

procedure T3DLinearMoving.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited;

  { Update sound position when object is moving }
  if (UsedSound <> nil) and SoundTracksCurrentPosition then
    UsedSound.Position := SoundPosition;

  { If the SoundGoBegin/EndPosition is longer than the MoveTime
    (or it's looping),
    stop this sound once we're completely in Begin/EndPosition. }
  if (AnimationTime - EndPositionStateChangeTime > MoveTime) and
    (UsedSound <> nil) then
    UsedSound.Release;
end;

{ TAlive ------------------------------------------------------------------- }

constructor TAlive.Create(AOwner: TComponent);
begin
  inherited;
  KnockBackSpeed := 1.0;
  { at the beginning we are Dead (Life = 0) and DieTime = LifeTime,
    so everything is already in the correct state. }
end;

procedure TAlive.SetLife(const Value: Single);
begin
  if (FLife > 0) and (Value <= 0) then
    FDieTime := LifeTime;
  FLife := Value;
end;

function TAlive.Dead: boolean;
begin
  Result := Life <= 0;
end;

procedure TAlive.Hurt(const LifeLoss: Single;
  const HurtDirection: TVector3;
  const AKnockbackDistance: Single; const Attacker: TAlive);
begin
  Life := Life - LifeLoss;
  FKnockbackDistance := AKnockbackDistance;
  FLastHurtDirection := HurtDirection;

  { calculate FLastHurtDirectionGround }
  FLastHurtDirectionGround := FLastHurtDirection;
  if Gravity then
    MakeVectorsOrthoOnTheirPlane(FLastHurtDirectionGround, World.GravityUp);
end;

procedure TAlive.CancelKnockback;
begin
  FKnockbackDistance := 0;
end;

procedure TAlive.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
{ Do the knockback effect, if it's currently active, by pushing
  creature along last attack direction. }
var
  CurrentKnockBackDistance: Single;
begin
  inherited;
  if not GetExists then Exit;

  FLifeTime := FLifeTime + SecondsPassed;

  if FKnockbackDistance > 0 then
  begin
    { Calculate CurrentKnockBackDistance, update FKnockbackDistance }
    CurrentKnockBackDistance := KnockBackSpeed * SecondsPassed;
    if FKnockbackDistance < CurrentKnockBackDistance then
    begin
      CurrentKnockBackDistance := FKnockbackDistance;
      FKnockbackDistance := 0;
    end else
      FKnockbackDistance := FKnockbackDistance - CurrentKnockBackDistance;

    Move(FLastHurtDirectionGround * CurrentKnockBackDistance, false);
  end;
end;

end.

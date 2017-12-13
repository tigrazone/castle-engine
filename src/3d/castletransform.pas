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
{ Group and transform 3D scenes (TCastleTransform). }
unit CastleTransform;

{$I castleconf.inc}

interface

uses SysUtils, Classes, Math, Generics.Collections, Kraft,
  CastleVectors, CastleFrustum, CastleBoxes, CastleClassUtils, CastleKeysMouse,
  CastleRectangles, CastleUtils, CastleTimeUtils,
  CastleSoundEngine, CastleSectors, CastleCameras, CastleTriangles;

type
  TSceneManagerWorld = class;
  TCastleTransform = class;

  TCastleTransformClass = class of TCastleTransform;

  ECannotAddToAnotherWorld = class(Exception);
  EMultipleReferencesInWorld = class(Exception);
  EPhysicsError = class(Exception);

  TRenderFromViewFunction = procedure of object;

  { Describe what visible thing changed for TCastleTransform.VisibleChangeHere. }
  TVisibleChange = (
    { Visible geometry (actual 3D shape) changed.
      It's not used when only light conditions, materials, textures
      and such changed.

      In practice, this means that the depth buffer from some point in space
      changed. Which means that shadow maps should be regenerated. }
    vcVisibleGeometry,

    { Something visible, but not the geometry shape, changes.
      For example, material or texture on a visible surface changed. }
    vcVisibleNonGeometry);
  TVisibleChanges = set of TVisibleChange;

  TVisibleChangeEvent = procedure (const Sender: TCastleTransform; const Changes: TVisibleChanges) of object;

  { Various things that TCastleTransform.PrepareResources may prepare. }
  TPrepareResourcesOption = (prRender, prBackground, prBoundingBox,
    prShadowVolume,
    { Prepare octrees (determined by things like TCastleSceneCore.Spatial). }
    prSpatial,
    prScreenEffects);
  TPrepareResourcesOptions = set of TPrepareResourcesOption;

  { Shadow volumes helper, not depending on OpenGL. }
  TBaseShadowVolumeRenderer = class
  end;

  TCastleTransformList = class;

  { Information about ray collision with a single 3D object.
    Everything (Point, RayOrigin, RayDirection) is expressed in the
    local coordinates of given 3D object (in @link(Item)). }
  TRayCollisionNode = object
  public
    { Colliding object. }
    Item: TCastleTransform;

    { Position, in local coordinate system of this 3D object,
      of the picked 3D point.

      If the ray hit empty space (@link(Item) field is @nil),
      then this is undefined.
      Note that only @link(TCastleSceneManager.MainScene) is informed about pointing
      device events when the ray hit empty space, so this is an unusual case.
    }
    Point: TVector3;

    { Triangle that was hit. This triangle is always a part of @link(Item).

      If the ray hit empty space (@link(Item) field is @nil),
      then this is @nil.
      Note that only @link(TCastleSceneManager.MainScene) is informed about pointing
      device events when the ray hit empty space, so this is an unusual case.

      May also be @nil if RayCollision implementation for the 3D object
      simply left it @nil. For example,

      @unorderedList(
        @item(If the collision occured with a TCastleSceneCore with
          @link(TCastleSceneCore.Spatial) that includes a collidable
          structure (ssDynamicCollisions or ssStaticCollisions),
          then this triangle is set.)

        @item(If the collision occured merely with a TCastleTransform bounding box,
          the triangle is left as @nil.)
      )
    }
    Triangle: PTriangle;

    { Ray used to cause the collision,
      in local coordinate system of this 3D object. }
    RayOrigin, RayDirection: TVector3;
  end;
  PRayCollisionNode = ^TRayCollisionNode;

  { Represents a @bold(ray) collision with a 3D objects tree.
    Just access the @code(First) item for the collision information
    with the final 3D object. The rest of items are containers of this 3D
    object (a path within @link(TCastleSceneManager.Items) hierarchy tree,
    usually).

    This list is a path in the TCastleTransform tree leading from the
    final colliding object (usually TCastleScene)
    to the root of the TCastleTransform tree.
    This allows you to track the TCastleTransform
    containers that contain given collision.

    This is never an empty list when returned by RayCollision. }
  TRayCollision = class({$ifdef CASTLE_OBJFPC}specialize{$endif} TStructList<TRayCollisionNode>)
  public
    { Distance, in world coordinate system, from the current
      camera to the picked point. The suggested usage is to decide if player
      is close enough to reach the 3D object --- for example, you may not
      want to allow player to open a door by clicking on it from a far distance.

      If the ray hit empty space, the distance is MaxSingle.
      Note that only MainScene is informed about pointing device events
      when the ray hit empty space. }
    Distance: Single;

    { Index of node with given Item, -1 if none. }
    function IndexOfItem(const Item: TCastleTransform): Integer;

    { Index of node with given ItemClass, -1 if none. }
    function IndexOfItem(const ItemClass: TCastleTransformClass): Integer;
  end;

  { Detailed information about collision with a single 3D object. }
  TCollisionDetailsItem = object
  public
    { Colliding 3D object. }
    Item: TCastleTransform;

    { Triangle that was hit. This triangle is always a part of @link(Item).

      May be @nil if the given collision implementation cannot determine
      this (not all 3D objects must have a simple array of triangles in memory).
      In practice, only TCastleSceneCore sets this now, and containers
      that eventually proxy the collisions to underlying TCastleSceneCore instances.

      If the ray hit empty space, this is @nil.
      Note that only TCastleSceneManager.MainScene is informed about pointing
      device events when the ray hit empty space, so this is an unusual case. }
    // Triangle: PTriangle;
  end;
  PCollisionDetailsItem = ^TCollisionDetailsItem;

  { Represents a collision with a 3D objects tree.
    Just access the @code(First) item for the collision information
    with the final 3D object. The rest of items are containers of this 3D
    object (a path within @link(TCastleSceneManager.Items) hierarchy tree,
    usually).

    This list is a path in the TCastleTransform tree leading from the
    final colliding object to the root of the TCastleTransform tree.
    This allows you to track the TCastleTransform
    containers that contain given collision.

    This is never an empty list when returned by XxxCollision method. }
  TCollisionDetails = class({$ifdef CASTLE_OBJFPC}specialize{$endif} TStructList<TCollisionDetailsItem>)
  public
    { Index of node with given Item. }
    function IndexOfItem(const Item: TCastleTransform): Integer;
    procedure Add(const Item: TCastleTransform);
  end;

  { Statistics about what was rendered during last frame.
    You will usually access this by scene manager property,
    see @link(TCastleAbstractViewport.Statistics). }
  TRenderStatistics = record
    { How many shapes were rendered (send to OpenGL)
      versus all shapes that were potentially visible.
      Potentially visible shapes are the ones with
      TShape.Visible inside a 3D object with TCastleTransform.GetExists.

      When ShapesRendered is much smaller than ShapesVisible,
      it means that the algorithm for removing invisible scene parts
      works good. This includes frustum culling (automatically
      used by TCastleScene), or occlusion culling (see
      TSceneRenderingAttributes.UseOcclusionQuery),
      or any custom algorithm you implement by using TTestShapeVisibility
      callback with @link(TCastleScene.Render). }
    ShapesRendered, ShapesVisible: Cardinal;

    { The number of shapes that were not rendered,
      but their bounding box was rendered to check with occlusion query.
      This is always zero when not using occlusion query (see
      TSceneRenderingAttributes.UseOcclusionQuery).
      Basically, this measures the "invisible overhead" of occlusion query. }
    BoxesOcclusionQueriedCount: Cardinal;
  end;

  { List of lights. Always TLightInstancesList, but we cannot declare it here
    as such. Internal. @exlude }
  TAbstractLightInstancesList = TObject;

  { Fog node. Always TFogNode, but we cannot declare it here as such.
    Internal. @exlude }
  TAbstractFogNode = TObject;

  TRenderingPass = 0..1;

  { Information that a TCastleTransform object needs to prepare rendering. }
  TPrepareParams = class
    { Include a headlight, or global lights that shine on all
      scenes (see @link(TCastleAbstractViewport.UseGlobalLights)).

      It is not necessary to define this (it may be @nil).
      And all the lighting is dynamic, so of course you can always
      turn on / off things like a headlight during the game.
      However, passing here the appropriate lights will mean that the shaders
      are immediately prepared for the current lighting.

      @exclude }
    InternalBaseLights: TAbstractLightInstancesList;
    { World fog, in any, to prepare for.
      @exclude }
    InternalGlobalFog: TAbstractFogNode;
  end;

  { Information that a TCastleTransform object needs to render.
    Read-only for TCastleTransform.Render
    (except Statistics, which should be updated during rendering). }
  TRenderParams = class
    { Which parts should be rendered: opaque (@false) or transparent (@true). }
    Transparent: boolean;

    { Should we render parts that may receive shadow volumes, or ones that don't.
      During rendering, simply check does it match TCastleScene.ReceiveShadowVolumes. }
    ShadowVolumesReceivers: boolean;

    { If @true, means that we're using multi-pass
      shadowing technique (like shadow volumes),
      and currently doing the "shadowed" pass.

      Which means that most lights (ones with shadowVolumes = TRUE)
      should be turned off, see [http://castle-engine.sourceforge.net/x3d_extensions.php#section_ext_shadows].) }
    InShadow: boolean;

    { Value > 0 means we're inside some stencil test (like for
      InShadow = @false pass of shadow volumes). }
    StencilTest: Cardinal;

    { Rendering pass number, for multi-pass rendering, like for shadow volumes. }
    Pass: TRenderingPass;

    { Transformation that should be applied to the rendered result.
      If RenderTransformIdentity, then RenderTransform is always identity.
      @groupBegin }
    RenderTransform: TMatrix4;
    RenderTransformIdentity: boolean;
    { @groupEnd }

    Statistics: TRenderStatistics;

    { Fog that affects all scenes. }
    GlobalFog: TAbstractFogNode;

    constructor Create;

    { Lights that shine on given 3D object. }
    function BaseLights(Scene: TCastleTransform): TAbstractLightInstancesList; virtual; abstract;
  end;

  TRemoveType = (rtNone, rtRemove, rtRemoveAndFree);

  { List of TCastleTransform instances.
    This inherits from TCastleObjectList, getting many
    features like TList notification mechanism.
    You should not create instances of this class yourself
    --- instead use TCastleTransform to group your scenes and transformations. }
  TCastleTransformList = class(TCastleObjectList)
  private
    FOwner: TCastleTransform;

    function GetItem(const I: Integer): TCastleTransform;
    procedure SetItem(const I: Integer; const Item: TCastleTransform);
  public
    constructor Create(const FreeObjects: boolean; const AOwner: TCastleTransform);
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
    property Items[I: Integer]: TCastleTransform read GetItem write SetItem; default;

    function First: TCastleTransform;
    function Last: TCastleTransform;

    { TCastleTransform instance that owns this list.
      May be @nil, for example when this list is used by TRayCollision. }
    property Owner: TCastleTransform read FOwner;
  end;

  { Orientation of the model is 3D world, determining where is
    the conceptual "up" direction of the model,
    and where is it facing. Used by the @link(TCastleTransform.Orientation)
    and @link(TCastleTransform.DefaultOrientation). }
  TOrientationType = (
    { Orientation sensible for models oriented around Y axis.
      That is when gravity pulls in -Y and GravityUp vector is +Y.
      Transformation makes -Z and +Y match (respectively) Direction and Up.

      This matches default direction/up of OpenGL and VRML/X3D cameras.

      For example, using this value for @link(TCastleTransform.Orientation) (or even
      @link(TCastleTransform.DefaultOrientation)) is sensible if you use default
      Blender X3D exporter, and you let the exporter to make
      a transformation (to make +Z up into +Y up). This is the default setting.
      Then you can follow the standard Blender view names
      ("front", "top" and such) when modelling, and Blender tools like
      "X-axis mirror" will work best. }
    otUpYDirectionMinusZ,

    { Orientation sensible for models oriented around Z axis.
      Transformation makes -Y and +Z match (respectively) Direction and Up.

      Using this value for @link(TCastleTransform.Orientation) (or even
      @link(TCastleTransform.DefaultOrientation)) is sensible if you export your models
      from Blender @italic(without transforming them during export).
      Note that @italic(this is not the default Blender X3D exporter behavior).
      But you can configure the exporter to work like this (not transform),
      and then you can follow the standard Blender view names
      ("front", "top" and such) when modelling. }
    otUpZDirectionMinusY,

    { @deprecated Up in +Z (like otUpZDirectionMinusY) and direction
      in +X. Should not be used in new models. }
    otUpZDirectionX
  );

  TRigidBody = class;

  { Group and transform (move, rotate, scale) children objects.

    Add and remove children using the @link(Add), @link(Remove) and similar methods.
    A child can be any @link(TCastleTransform) instance,
    in particular it can be a @link(TCastleScene) instance
    (which allows to load and render any 3D or 2D model).

    Control the transformation using these properties:

    @orderedList(
      @item(Move using @link(Translation).)

      @item(Rotate using @link(Rotation).
        The rotation is performed around the @link(Center) point.
        The rotation may be alternatively controlled using the
        @link(Direction) and @link(Up) vectors.)

      @item(Change size using @link(Scale).
        Scale is done around @link(Center) and with orientation given by
        @link(ScaleOrientation).)
    )

    This class is the base object that is managed by the @link(TCastleSceneManager).
    You insert instances of this class into @link(TCastleSceneManager.Items),
    which is actually an instance of @link(TCastleTransform) too.

    This class implements also optional gravity and physics.
    See the @link(Gravity) property for a simple unrealistic gravity model.
    See the @link(RigidBody) for a proper rigid-bidy simulation,
    with correct gravity model and collisions with other rigid bodies. }
  TCastleTransform = class(TComponent)
  private
    FCastShadowVolumes: boolean;
    FExists: boolean;
    FCollides: boolean;
    FPickable: boolean;
    FVisible: boolean;
    FCursor: TMouseCursor;
    FCollidesWithMoving: boolean;
    Disabled: Cardinal;
    FExcludeFromGlobalLights, FExcludeFromStatistics,
      FInternalExcludeFromParentBoundingVolume: boolean;
    FWorld: TSceneManagerWorld;
    FWorldReferences: Cardinal;
    FList: TCastleTransformList;

    // transformation
    FCenter: TVector3;
    FRotation: TVector4;
    FScale: TVector3;
    FScaleOrientation: TVector4;
    FTranslation: TVector3;

    // transformation extras
    FGravity: boolean;
    FFallingStartMiddle: TVector3;
    FFalling: boolean;
    FFallSpeed: Single;
    FGrowSpeed: Single;
    FMiddleHeight: Single;
    FRigidBody: TRigidBody;
    FOrientation: TOrientationType;
    FOnlyTranslation: boolean;

    procedure SetCursor(const Value: TMouseCursor);
    procedure SetCenter(const Value: TVector3);
    procedure SetRotation(const Value: TVector4);
    procedure SetScale(const Value: TVector3);
    procedure SetScaleOrientation(const Value: TVector4);
    procedure SetTranslation(const Value: TVector3);
    procedure SetRigidBody(const Value: TRigidBody);
    function GetDirection: TVector3;
    function GetUp: TVector3;
    procedure SetDirection(const Value: TVector3);
    procedure SetUp(const Value: TVector3);
    function RotationFromDirectionUp(const D, U: TVector3): TVector4;
    function RotationToDirection(const ARotation: TVector4): TVector3;
    function RotationToUp(const ARotation: TVector4): TVector3;
    procedure UpdateSimpleGravity(const SecondsPassed: Single);
    procedure UpdatePhysicsEngine(const SecondsPassed: Single);
    function GetItem(const I: Integer): TCastleTransform;
    procedure SetItem(const I: Integer; const Item: TCastleTransform);
    procedure PhysicsDestroy;
    procedure PhysicsNotification(AComponent: TComponent; Operation: TOperation);
    procedure PhysicsChangeWorldDetach;
    procedure PhysicsChangeWorldAttach;
  protected
    { Workaround for descendants where BoundingBox may suddenly change
      but their logic depends on stable (not suddenly changing) Middle.
      If MiddleForceBox then we will use given MiddleForceBoxValue
      instead of LocalBoundingBox for Middle and PreferredHeight
      calculation. Descendants that deal with this should usually have
      some timeout when they restore MiddleForceBox to false.

      This is quite internal hack and you should not use this in your own programs.
      This is used only by TWalkAttackCreature.
      @exclude
      @groupBegin }
    MiddleForceBox: boolean;
    { @exclude }
    MiddleForceBoxValue: TBox3D;
    { @groupEnd }

    { Change to new world, or (if not needed) just increase FWorldReferences.
      Value must not be @nil. }
    procedure AddToWorld(const Value: TSceneManagerWorld);

    { Decrease FWorldReferences, then (if needed) change world to @nil.
      Value must not be @nil. }
    procedure RemoveFromWorld(const Value: TSceneManagerWorld);

    { Called when the current 3D world (which corresponds to the current
      TCastleSceneManager) of this 3D object changes.
      This can be ignored (not care about FWorldReferences) when Value = FWorld.

      Each 3D object can only be part of one TSceneManagerWorld at a time.
      The object may be present many times within the world
      (counted by FWorldReferences, which is always set to 1 by this procedure
      for non-nil Value, and 0 for nil Value).
      Always remove 3D object from previous world (scene manager)
      before adding it to new one. }
    procedure ChangeWorld(const Value: TSceneManagerWorld); virtual;

    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    { Height of a point above the 3D model.
      This checks ray collision, from APosition along the negated GravityUp vector.
      Measures distance to the nearest scene item (called "ground" here).

      @returns(If the 3D scene is hit.
        @false means that APosition floats above an empty space.
        That is, if you turn gravity on, it will fall down forever,
        as far as this 3D scene is concerned.)

      @param(AboveHeight Height above the ground.
        @italic(One height unit equals one GravityUp vector).
        Always use normalized GravityUp vector if you expect
        to receive here a normal distance.

        AboveHeight is always set to MaxSingle when returned result is @false
        (this guarantee simplifies some code).)

      @param(AboveGround Pointer to PTriangle representing the ground.
        Must be @nil if returned result is @false.
        @bold(May) be @nil even if we returned @true (not all 3D
        objects may be able to generate PTriangle information about collision).

        This may be useful for example to make a footsteps sound dependent
        on texture of the ground.
        Or to decrease player life points for walking on hot lava.
        See "The Castle" game for examples.)
    }
    function HeightCollision(const APosition, GravityUp: TVector3;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc;
      out AboveHeight: Single; out AboveGround: PTriangle): boolean;

    { Can other 3D object (maybe a player) move without colliding with this object.

      If IsRadius, then you should prefer to perform exact collision with sphere
      of given radius (must be > 0).
      At the very least, this checks that the line segment
      between OldPos and NewPos doesn't collide,
      @bold(and) that sphere with given Radius centered around NewPos
      doesn't collide.

      If not IsRadius, or if checking for collisions with sphere is not possible
      for some reasons, then you can check for collisions with boxes.
      OldBox should usually be ignored (it can be useful when collision-checking
      has to be approximate in some corner cases, see TCreature.MoveCollision).
      NewBox plays the same role as "sphere centered around NewPos" in paragraph
      above.

      Overloaded version with separate ProposedNewPos and NewPos parameters
      allows you to accept the move, but for NewPos (that should be some slightly
      modified version of ProposedNewPos). This allows to implement wall-sliding:
      when camera tries to walk into the wall, we will change movement
      to move alongside the wall (instead of just completely blocking the move).
      When this version returns @false, it's undefined what is the NewPos.

      @groupBegin }
    function MoveCollision(
      const OldPos, ProposedNewPos: TVector3; out NewPos: TVector3;
      const IsRadius: boolean; const Radius: Single;
      const OldBox, NewBox: TBox3D;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean; overload;
    function MoveCollision(
      const OldPos, NewPos: TVector3;
      const IsRadius: boolean; const Radius: Single;
      const OldBox, NewBox: TBox3D;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean; overload;
    { @groupEnd }

    function SegmentCollision(const Pos1, Pos2: TVector3;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc;
      const ALineOfSight: boolean): boolean;
    function SphereCollision(const Pos: TVector3; const Radius: Single;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean;

    { Check collision with a sphere in 2D (a circle, extruded to infinity along the Z axis).

      Note that PointCollision2D and SphereCollision2D @italic(do not work
      reliably on objects that have 3D rotations). See @link(PointCollision2D)
      for details.

      @param(Details If non-nil, these are automatically filled with the details
        about the collision.
        If the result is @false, the Details contents are untouched.
        If the result is @true, the Details contents are set to describe
        the 3D objects hierarchy that caused this collision.) }
    function SphereCollision2D(const Pos: TVector2; const Radius: Single;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc;
      const Details: TCollisionDetails = nil): boolean;

    { Check collision with a point in 2D (which is an infinite line along the Z axis
      in 3D).

      Note that PointCollision2D and SphereCollision2D @italic(do not work
      reliably on objects that have 3D rotations), that is: rotations that change
      the direction of Z axis! This applies to all ways of rotating --
      using the @link(TCastleTransform)
      or using the X3D node @link(TTransformNode) (within a TCastleSce).

      @orderedList(
        @item(@italic(The reason): we transform the point (or sphere center)
          to the local coordinates, and we should also transform the Z axis to
          the local coordinates, to be always correct. Right now, we don't do
          the latter.)

        @item(And we don't want to do it (at least not in all cases)!
          The simple 2D point collision check would then actually perform
          a 3D line collision check, thus PointCollision2D would lose all the speed
          benefits over LineCollision. PointCollision2D would become
          a simple shortcut to perform @italic(LineCollision with
          a line parallel to Z axis).

          And in case of 2D games, or mostly 2D games, this speed loss
          would not be justified. Often you @italic(know) that your objects
          have no 3D rotations, for example if your animations are done in Spine.)

        @item(In the future, we may overcome this limitation.
          To do this, we will detect whether the transformation is "only 2D"
          (actually this part is easy, you can detect it by looking at the matrix
          even, so check whether appropriate numbers are zero).
          And then PointCollision2D will change to LineCollision,
          and SphereCollision2D will change to something like ExtrudedCircleCollision,
          @italic(only when necessary).)
      )
    }
    function PointCollision2D(const Point: TVector2;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean;

    function BoxCollision(const Box: TBox3D;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean;

    { Check collision with a ray, building a TRayCollision result.
      Returns a collision as TRayCollision instance, or @nil if no collision.
      Caller is responsible for freeing the returned TRayCollision instance.

      Contrary to other collision routines, this should @italic(ignore
      the @link(Collides) property). The @link(Collides) property
      specifies whether item collides with camera. And this method is used
      for picking (pointing) 3D stuff --- everything visible can be picked,
      collidable or not. Instead, this looks at @link(Pickable) property
      (actually, at @link(GetPickable) method result).

      This always returns the first collision with the 3D world, that is
      the one with smallest TRayCollision.Distance. For example, when
      implemented in TCastleTransform, this checks collisions for all list items,
      and chooses the closest one. }
    function RayCollision(const RayOrigin, RayDirection: TVector3;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): TRayCollision;

    function LocalHeightCollision(const APosition, GravityUp: TVector3;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc;
      out AboveHeight: Single; out AboveGround: PTriangle): boolean; virtual;
    function LocalMoveCollision(
      const OldPos, ProposedNewPos: TVector3; out NewPos: TVector3;
      const IsRadius: boolean; const Radius: Single;
      const OldBox, NewBox: TBox3D;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean; virtual;
    function LocalMoveCollision(
      const OldPos, NewPos: TVector3;
      const IsRadius: boolean; const Radius: Single;
      const OldBox, NewBox: TBox3D;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean; virtual;
    function LocalSegmentCollision(const Pos1, Pos2: TVector3;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc;
      const ALineOfSight: boolean): boolean; virtual;
    function LocalSphereCollision(const Pos: TVector3; const Radius: Single;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean; virtual;
    function LocalSphereCollision2D(const Pos: TVector2; const Radius: Single;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc;
      const Details: TCollisionDetails = nil): boolean; virtual;
    function LocalPointCollision2D(const Point: TVector2;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean; virtual;
    function LocalBoxCollision(const Box: TBox3D;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): boolean; virtual;
    function LocalRayCollision(const RayOrigin, RayDirection: TVector3;
      const TrianglesToIgnoreFunc: TTriangleIgnoreFunc): TRayCollision; virtual;

    { Render with given Params (includes a full transformation of this scene). }
    procedure LocalRender(const Frustum: TFrustum; const Params: TRenderParams); virtual;

    { Render shadow volumes (with a full transformation of this scene). }
    procedure LocalRenderShadowVolume(
      ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
      const ParentTransformIsIdentity: boolean;
      const ParentTransform: TMatrix4); virtual;

    { Can we use simple @link(Translation) instead of full TransformMatricesMult.
      Returning @true allows optimization in some cases.
      @bold(Internal. Protected instead of private only for testing.)
      @exclude }
    function OnlyTranslation: boolean;

    { Get translation in 2D (uses @link(Translation), ignores Z coord). }
    function Translation2D: TVector2;

    { Transformation matrix.
      This method produces matrices that preserve points as points
      and directions as directions in homegeneous space.
      In other words, using TMatrix4.MultPoint or TMatrix4.MultDirection
      with these matrices must never raise ETransformedResultInvalid.
      For example, a combination of translations, rotations, scaling is Ok. }
    procedure TransformMatricesMult(var M, MInverse: TMatrix4);
    procedure TransformMatrices(out M, MInverse: TMatrix4);

    { Average value of 3D scale in @link(Scale).
      It is not calculated as a simple average, it's a little smarter
      to prevent from weird results sometimes, see @link(Approximate3DScale). }
    function AverageScale: Single;

    { Average value of 2D scale, from XY components of @link(Scale).
      It is not calculated as a simple average, it's a little smarter
      to prevent from weird results sometimes, see @link(Approximate2DScale). }
    function AverageScale2D: Single;

    { Called when fall ended. You can use FallHeight to decrease creature
      life or such. }
    procedure Fall(const FallHeight: Single); virtual;

    { Override this to be notified about every transformation change.
      By default, this calls VisibleChangeHere, which causes the window to redraw. }
    procedure ChangedTransform; virtual;
  public
    const
      DefaultMiddleHeight = 0.5;
      DefaultDirection: array [TOrientationType] of TVector3 = (
        (Data: (0,  0, -1)),
        (Data: (0, -1,  0)),
        (Data: (1,  0,  0))
      );
      DefaultUp: array [TOrientationType] of TVector3 = (
        (Data: (0, 1, 0)),
        (Data: (0, 0, 1)),
        (Data: (0, 0, 1))
      );

    var
      { Default value of @link(TCastleTransform.Orientation) for new instances. }
      DefaultOrientation: TOrientationType; static;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Does item really exist, see @link(Exists) and @link(Enable),
      @link(Disable).
      It TCastleTransform class, returns @true if @link(Exists) and not disabled.
      May be modified in subclasses, to return something more complicated. }
    function GetExists: boolean; virtual;

    { Does item really collide, see @link(Collides).
      It TCastleTransform class, returns @link(Collides) and @link(GetExists).
      May be modified in subclasses, to return something more complicated. }
    function GetCollides: boolean; virtual;

    { Is item really pickable, see @link(Pickable).
      It TCastleTransform class, returns @link(Pickable) and @link(GetExists).
      May be modified in subclasses, to return something more complicated. }
    function GetPickable: boolean; virtual;

    { Is item really visible, see @link(Visible).
      It v class, returns @link(Visible) and @link(GetExists).
      May be modified in subclasses, to return something more complicated. }
    function GetVisible: boolean; virtual;

    { Is this object visible and colliding.

      Setting this to @false pretty much turns everything of this 3D object
      to "off". This is useful for objects that disappear completely from
      the level when something happens. You could just as well remove
      this object from @link(TCastleSceneManager.Items) tree, but sometimes it's more
      comfortable to simply turn this property to @false.

      Descendants may also override GetExists method.

      @noAutoLinkHere }
    property Exists: boolean read FExists write FExists default true;

    { Items that are at least once disabled are treated like not existing.
      Every @link(Disable) call should always be paired with @link(Enable) call
      (usually using @code(try ... finally .... end) block).
      Internally, we keep a counter of how many times the object is disabled,
      and if this counter is <> 0 then GetExists returns @false.
      Using this is useful for taming collisions, especially to avoid self-collisions
      (when a creature moves, it checks for collision with other creatures,
      but it doesn't want to check for collisions with it's own bounding volume).
      @groupBegin }
    procedure Disable;
    procedure Enable;
    { @groupEnd }

    { Should this 3D object participate in collision detection.
      You can turn this off, useful to make e.g. "fake" walls
      (to some secret places on level).

      This describes collision resolution with almost everything --- camera,
      player (in third-person perspective, camera may differ from player),
      other creatures. That is because everything
      resolves collisions through our methods MoveCollision and HeightCollision
      (high-level) or SegmentCollision, SphereCollision, SphereCollision2D,
      PointCollision2D, BoxCollision (low-level).

      (Note that RayCollision is excluded from this,
      it exceptionally ignores Collides value, as it's primarily used for picking.
      Same for SegmentCollision with LineOfSight=true.)

      The only exception are the collisions with T3DMoving instances
      (movable world parts like elevators and doors) that have their own
      detection routines and look at CollidesWithMoving property of other objects.
      That is, the T3DMoving instance itself must still have Collides = @true,
      but it interacts with @italic(other) objects if and only if they have
      CollidesWithMoving = @true (ignoring their Collides value).
      This allows items to be moved by elevators, but still player and creatures
      can pass through them.

      Note that if not @link(Exists) then this doesn't matter
      (not existing objects never participate in collision detection).

      Descendants may also override GetCollides method. Sometimes it's more
      comfortable than changing the property value.

      @noAutoLinkHere }
    property Collides: boolean read FCollides write FCollides default true;

    { Is item pickable by @link(RayCollision) method.
      Note that if not @link(Exists) then this doesn't matter
      (not existing objects are never pickable).
      This is independent from @link(Collides), as @link(RayCollision)
      does not look at @link(Collides), it only looks at @link(Pickable).

      Descendants may also override GetPickable method. Sometimes it's more
      comfortable than changing the property value.

      @noAutoLinkHere }
    property Pickable: boolean read FPickable write FPickable default true;

    { Is item visible.
      Note that if not @link(Exists) then this doesn't matter
      (not existing objects are never visible).
      This is independent from @link(Collides) or @link(Pickable).

      Descendants may also override GetVisible method. Sometimes it's more
      comfortable than changing the property value.

      @noAutoLinkHere }
    property Visible: boolean read FVisible write FVisible default true;

    { Operate on 3D objects contained in the list.
      You can also operate directly on @link(List) instance.
      @groupBegin }
    procedure Add(const Item: TCastleTransform);
    procedure Insert(const Index: Integer; const Item: TCastleTransform);
    procedure Remove(const Item: TCastleTransform);
    property Items[I: Integer]: TCastleTransform read GetItem write SetItem; default;
    function Count: Integer;
    procedure Clear;
    procedure Exchange(const Index1, Index2: Integer);
    { @groupEnd }

    { Sort objects back-to-front @italic(right now)
      following one of the blending sorting algorithms.
      Only the immediate list items are reordered,
      looking at their bounding boxes.

      Calling this method makes sense if you have a list
      of objects, and some of them are partially-transparent and may
      be visible at the same place on the screen.
      It may even make sense to call this method every frame (like in every
      @link(TCastleWindowCustom.OnUpdate)),
      if you move or otherwise change the objects (changing their bounding boxes),
      or if the CameraPosition may change (note that CameraPosition is only
      relevant if BlendingSort = bs3D).

      Sorting partially-transparent objects avoids artifacts when rendering.

      Note that this doesn't take care of sorting the shapes
      within the scenes. For this, you should set
      @link(TSceneRenderingAttributes.BlendingSort Scene.Attributes.BlendingSort)
      to a value like bs3D, to keep it sorted.
      It is actually the default now.

      See the TBlendingSort documentation for the exact specification
      of sorting algorithms. Using BlendingSort = bsNone does nothing. }
    procedure SortBackToFront(const BlendingSort: TBlendingSort;
      const CameraPosition: TVector3);

    { Sort objects back-to-front @italic(right now)
      following the 2D blending sorting algorithm.
      See @link(SortBackToFront) for documentation, this method
      is only a shortcut for @code(SortBackToFront(bs2D, TVector3.Zero)). }
    procedure SortBackToFront2D;

    { Bounding box of the 3D object.

      Should take into account both collidable and visible objects.
      For example, invisible walls (not visible) and fake walls
      (not collidable) should all be accounted here.

      It's a @italic(bounding) volume, it should be as large as necessary
      to include the object inside. At the same time, it should be
      as "tight" as it can, to make various optimizations work best. }
    function BoundingBox: TBox3D;

    { Bounding box assuming that the scene is not transformed. }
    function LocalBoundingBox: TBox3D; virtual;

    { Render given object.
      Should check and immediately exit when @link(GetVisible) is @false.
      Should render only parts with matching Params.Transparency
      and Params.ShadowVolumesReceivers values (it may be called
      more than once to render frame).

      @param(Frustum May be used to optimize rendering, to not
        render the parts outside the Frustum.)

      @param(Params Other parameters helpful for rendering.)
    }
    procedure Render(const Frustum: TFrustum; const Params: TRenderParams);

    { Does the 3D object cast shadows by shadow volumes.
      See also TCastleScene.ReceiveShadowVolumes. }
    property CastShadowVolumes: boolean
      read FCastShadowVolumes write FCastShadowVolumes default true;

    { Render shadow quads for all the things rendered by @link(Render).
      This is done only if @link(Exists) and @link(CastShadowVolumes).

      It does shadow volumes culling inside (so ShadowVolumeRenderer should
      have FrustumCullingInit already initialized).

      ParentTransform and ParentTransformIsIdentity describe the transformation
      of this object in the 3D world.
      TCastleTransform objects may be organized in a hierarchy when
      parent transforms it's children. When ParentTransformIsIdentity,
      ParentTransform must be TMatrix4.Identity (it's not guaranteed
      that when ParentTransformIsIdentity = @true, Transform value will be
      ignored !). }
    procedure RenderShadowVolume(
      ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
      const ParentTransformIsIdentity: boolean;
      const ParentTransform: TMatrix4);

    { Prepare resources, making various methods (like rendering and such)
      to execute fast.

      It is usually simpler to call @link(TCastleSceneManager.PrepareResources)
      then this method. Calling @code(SceneManager.PrepareResources(MyScene))
      will automatically call @code(MyScene.PrepareResources(...)) underneath,
      with proper parameters.

      It is best to call this after the rendering context is initailized,
      which means: at Application.OnInitialize, or Window.OnOpen or later.
      Calling this method earlier will omit some preparations,
      thus reducing the effectiveness of them.

      This makes sure that appropriate methods execute as fast as possible.
      It's never required to call this method
      --- everything will be prepared "as needed" anyway.
      But if you allow everything to be prepared "as needed",
      then e.g. the first @link(Render) call may take a long time because it may
      have to prepare resources that will be reused in next @link(Render) calls.
      This is bad, as your program will seem very slow at the beginning
      (when rendering resources are being prepared, so at first frame,
      or a couple of first animation frames). To avoid this, call this method,
      showing the user something like "now we're preparing
      the resources --- please wait".

      For OpenGL rendered objects, this method ties this object
      to the current OpenGL context.
      But it doesn't change any OpenGL state or buffers contents
      (at most, it allocates some texture and display list names).

      @param(Options What features should be prepared to execute fast.
        See TPrepareResourcesOption,
        the names should be self-explanatory (they refer to appropriate
        methods of TCastleTransform, TCastleSceneCore or TCastleScene).)

      @param(ProgressStep Says that we should make this many Progress.Step calls
        during preparation.
        Useful to show progress bar to the user during long preparation.

        TODO: for now, do not include prSpatial if you use ProgressStep.
        Reason: octree preparations have a separate mechanism
        that may want to show progress.)

      @param(Params
        Rendering parameters to prepare for.
        It is used only if Options contains prRender.
      ) }
    procedure PrepareResources(const Options: TPrepareResourcesOptions;
      const ProgressStep: boolean; const Params: TPrepareParams); virtual;

    { How many times PrepareResources will call Progress.Step.
      Useful only if you want to pass ProgressStep = @true to PrepareResources.
      In the base class TCastleTransform this just returns 0.  }
    function PrepareResourcesSteps: Cardinal; virtual;

    { Press and release events of key and mouse. Return @true if you handled them.
      See also TUIControl analogous events.
      @groupBegin }
    function Press(const Event: TInputPressRelease): boolean; virtual;
    function Release(const Event: TInputPressRelease): boolean; virtual;
    { @groupEnd }

    { Pointing device (usually mouse) events.
      Return @true if you handled the event.

      @unorderedList(
        @item(PointingDeviceActivate signals that the picking button (usually,
          left mouse button) is pressed or released (depending on Active parameter).

          Note that the exact key or mouse responsible for this is configurable
          in our engine by Input_Interact. By default it's the left mouse button,
          as is usual for VRML/X3D browsers. But it can be configured to be other
          mouse button or a key, for example most 3D games use "e" key to interact.

          In case of Active = @false (which means that pointing device
          is no longer pressed), an extra parameter CancelAction indicates
          whether this pointing device "press and release" sequence may be
          considered a "click". When CancelAction = @true, then you should not make
          a "click" event (e.g. TouchSensor should not send touchTime event etc.).

          In case of Active = @true, CancelAction is always @false.
        )

        @item(PointingDeviceMove signals that pointer moves over this 3D object.)
      )

      PointingDeviceMove receives Pick information about what exactly is hit
      by the 3D ray corresponding to the current mouse position.
      It contains the detailed information about 3D point, triangle
      and ray (all in local coordinate system) that are indicated by the mouse.
      PointingDeviceActivate does not receive this information now
      (because it may happen in obscure situations when ray direction is not known;
      this is all related to our "fallback to MainScene" mechanism).

      They also receive Distance to the collision,
      in world coordinates. See TRayCollision.Distance.

      The pointing device event (activation,
      deactivation or move) is send first to the innermost 3D object.
      That is, we first send this event to the first item on
      TRayCollision list corresponding to the current ray.
      This way, the innermost ("most local") 3D object has the chance
      to handle this event first. If the event is not handled, it is passed
      to other 3D objects (we simply iterate over the TRayCollision list).
      If nothing on TRayCollision list
      handled the item, it is eventually passed to main 3D scene
      (TCastleSceneManager.MainScene), if it wasn't already present on
      TRayCollision list.

      Note that when passing this event to TCastleSceneManager.MainScene,
      it is possible that 3D ray simply didn't hit anything (mouse pointer
      is over the background). In this case, TRayCollisionNode.Point
      is undefined, TRayCollisionNode.Triangle is @nil
      and Distance is MaxSingle.

      This event should be handled only if GetExists.
      Usually, 3D objects with GetExists = @false will not be returned
      by RayCollision, so they will not receive this event anyway.
      However, if 3D object may be equal to TCastleSceneManager.MainScene,
      then it should be secured and check for GetExists
      inside PointingDeviceActivate and PointingDeviceMove.

      @groupBegin }
    function PointingDeviceActivate(const Active: boolean;
      const Distance: Single; const CancelAction: boolean = false): boolean; virtual;
    function PointingDeviceMove(const Pick: TRayCollisionNode;
      const Distance: Single): boolean; virtual;
    { @groupEnd }

    { Continously occuring event, for various tasks.
      @param(RemoveMe Set this to rtRemove or rtRemoveAndFree to remove
        this item from 3D world (parent list) after Update finished.
        rtRemoveAndFree additionally will free this item.
        Initially it's rtNone when this method is called.) }
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); virtual;

    { Something visible changed inside @italic(this) 3D object.
      This is usually called by implementation of this 3D object,
      to notify others that it changed.

      Changes is a set describing what changes occurred.
      See TVisibleChange docs for more information.
      It must specify all things that possibly changed.

      Changes can be [], meaning "something tells us to redraw, but no visible change
      happened yet, maybe something will happen during a redraw"
      (this is used when e.g. possibly LOD level changed).
      We still broadcast VisibleChangeNotification, even when Changes=[].

      The information about visibility changed is passed upward,
      to the Parent, and eventually to the TCastleSceneManager,
      that broadcasts this to all 3D objects
      by VisibleChangeNotification. If you want to @italic(react) to visibility
      changes, you should override VisibleChangeNotification,
      not this method.

      Be careful when handling this, various changes may cause this,
      so be prepared to handle this at every time. }
    procedure VisibleChangeHere(const Changes: TVisibleChanges); virtual;

    { World containing this 3D object. In other words, the root of 3D objects
      tree containing this object. In practice, the world instance
      is always 1-1 corresponding to a particular TCastleSceneManager instance
      (each scene manager has it's world instance in @link(TCastleSceneManager.Items)).

      @nil if we are not part of a hierarchy rooted in TSceneManagerWorld.
      In pratice, this happens if we're not yet part of a @link(TCastleSceneManager.Items)
      hierarchy. }
    property World: TSceneManagerWorld read FWorld;

    { Something visible changed in the world.
      This is usually called by our container (like TCastleSceneManager),
      to allow this object to react (e.g. by regenerating mirror textures)
      to changes in the world (not necessarily in this object,
      maybe in some other TCastleScene instance).

      If you want to @italic(react) to visibility
      changes, you should override this. }
    procedure VisibleChangeNotification(const Changes: TVisibleChanges); virtual;

    { Main camera observing this 3D object changed.
      This is usually called by our container (like TCastleSceneManager)
      to notify that camera changed. }
    procedure CameraChanged(ACamera: TCamera); virtual;

    { Mouse cursor over this object. }
    property Cursor: TMouseCursor read FCursor write SetCursor default mcDefault;

    { Called when OpenGL context of the window is destroyed.
      This will be also automatically called from destructor.

      Control should clear here any resources that are tied to the GL context. }
    procedure GLContextClose; virtual;

    procedure UpdateGeneratedTextures(
      const RenderFunc: TRenderFromViewFunction;
      const ProjectionNear, ProjectionFar: Single;
      const OriginalViewport: TRectangle); virtual;

    { Are we in the middle of dragging something by moving the mouse.

      This should be set to @true to disable camera navigation
      methods that also use mouse move. In practice, to disable TExamineCamera
      view rotation/movement by moving the mouse, as it makes (comfortable)
      dragging practically impossible (at each mouse move, view changes...).

      In particular, when you operate on active X3D pointing-device sensors
      (like drag sensors, e.g. PlaneSensor, but also TouchSensor may
      use it). }
    function Dragging: boolean; virtual;

    { Middle point, usually "eye point", of the 3D model.
      This is used for sphere center (if overriden Sphere returns @true)
      and is the central point from which collisions of this object
      are checked (Move, MoveAllowed, Height, LineOfSight).
      For 3D things like level scene this is mostly useless (as you will leave
      Sphere at default @false then, and the scene itself doesn't move),
      but it's crucial for dynamic 3D things like player and moving creatures.

      In short, it's usually most comfortable to think about this as
      a position of the eye, or the middle of the creature's head.

      In an ideal situation, it should not be based on anything dynamic.
      For example, when this is based on the current bounding box of the animation,
      there is a risk that a large and sudden change in animation
      box could make the Middle point to jump to the other side of
      the wall (breaking collisions, as it changes Middle without a chance
      to check for collisions by MoveAllowed).
      Ideally, it should remain constant even when the shape of the object changes,
      and be possible to change only when MoveAllowed is checked
      (so only when @link(TCastleTransform.Translation) can change).

      In this class this returns something sensible above the bottom
      of the box. See @link(TCastleTransform.MiddleHeight). }
    function Middle: TVector3; virtual;

    { Sector where the middle of this 3D object is.
      Used for AI. @nil if none (maybe because we're not part of any world,
      maybe because sectors of the world were not initialized,
      or maybe simply because we're outside of all sectors). }
    function Sector: TSector;

    { Can the approximate sphere (around Middle point)
      be used for some collision-detection
      tasks. If @true then Radius (and Middle point) determine the approximate
      sphere surrounding the 3D object (it does not have to be a perfect
      bounding sphere around the object), and it may be used for some
      collisions instead of BoundingBox.
      See @link(CollidesWithMoving) and @link(MoveAllowed) for when it may happen.

      Must return @false when not GetExists (because we can't express
      "empty sphere" by @link(Sphere) method for now, but BoundingBox can express
      TBox3D.Empty).

      By default, in TCastleTransform class, this always returns @false
      and @link(Sphere) is undefined.

      The advantages of using a sphere, that does not have to be a perfect
      bounding sphere (it may be smaller than necessary, and only
      account e.g. for upper body part of the creature), are:

      @unorderedList(
        @item(It can have constant radius, even though the actual
          creature animates. This allows us to perfectly, reliably guarantee
          that sphere absolutely never collides with level and such.

          In case of a tight bounding volume (box or sphere) that animates,
          this guarantee is not really possible. Simply increasing time changes
          the animation to the next frame, which may be slightly larger
          in one dimension because e.g. creature moves a hand in this direction.
          This means that simply increasing time may change the non-collidable
          creature into a collidable one, if creature stands close to a wall/other
          creature and such. And we cannot simply stop/reverse an arbitrary animation
          at an arbitrary time (to avoid collision), this would look weird
          for some animations and would require some additional work
          at preparing animations and designing AI (as then "every action can
          be interrupted").

          Also using a bounding volume large enough to account for all
          possible positions is not doable, as it would be too large.
          Consider that for humanoid creatures, walking animation usually
          has tall and thin bounding box (creature stands) but dead/lying animation
          usually has flat and wide bounding box.

          So, only a bounding volume (like a sphere) that
          @italic(may be smaller than bounding volume) can remain constant
          and easily guarantee the assertion "it never collides".

          This means that using such sphere results in simpler collision
          detection routines, as they may assume that collision doesn't occur.
          In contrast, detection routines looking at our (possibly animated)
          BoundingBox must take into account that collision may already be happening,
          and they must incorporate code to allow creatures/players to "get unstruck".)

        @item(Using smaller sphere also allows to naturally ascend the stairs
          and upward slopes. Sphere can move forward slightly, and then creature
          may raise up, to reach it's preferred height. Then sphere can move
          further forward, and so on. This alllows to allow stair climbing
          for creatures without any extra effort in the code.

          The downside is that creature legs will temporarily "sink into the floor"
          when climbing up the stairs. But it's not noticeable if "growing up"
          mechanism works fast enough.)
      )

      Sphere disadvantage:

      @unorderedList(
        @item(Sphere is far from perfect as a bounding volume --- it's too small,
          sometimes also too large, sometimes both at the same time...

          Since the Sphere radius remains always the same, it must be good
          for many creature animation frames. In cases where the sphere
          isn't suitable, and you don't need advantages above --- you can
          make @name return @false.
          E.g. a dead creature may be stuck in a wall,
          and it doesn't have to climb stairs. So you don't really need
          sphere advantages listed above, and @name may return @false
          when creature is in dying state.

          But still it may be a problem sometimes, if some creature states
          have entirely different animations and bounding boxes. Then you
          will be forced to choose one universal Radius for all creature
          states. And you need constant radius to keep the advantage above
          of "guarantee".

          1. Obviously you can't set radius too small, because if it's much smaller
          than actual creature's geometry then the creature will noticeably collide
          with level geometry and other creatures.

          2. On the other hand, you can't set radius too large
          (or move sphere center, Middle, much lower).
          This would block stair climbing.
        )
      ) }
    function Sphere(out Radius: Single): boolean; virtual;

    { Can this object be pushed by (or block movement of) doors, elevators
      and other moving level parts (T3DMoving instances).

      Some 3D moving objects may try to avoid crushing this item.
      Like an automatic door that stops it's closing animation
      to not crush things standing in the doorway.

      Some other 3D moving objects may push this object.
      Like elevators (vertical, or horizontal moving platforms).
      We may use sphere (see @link(TCastleTransform.Sphere)) for checking
      collisions, or bounding box (@link(TCastleTransform.BoundingBox)), depending on need. }
    property CollidesWithMoving: boolean read FCollidesWithMoving write FCollidesWithMoving default false;

    { Get height of my point above the rest of the 3D world.

      This ignores the geometry of this 3D object (to not accidentaly collide
      with your own geometry), and checks collisions with the rest of the world.
      @groupBegin }
    function Height(const MyPosition: TVector3;
      out AboveHeight: Single): boolean; overload;
    function Height(const MyPosition: TVector3;
      out AboveHeight: Single; out AboveGround: PTriangle): boolean; overload;
    { @groupEnd }

    function LineOfSight(const Pos1, Pos2: TVector3): boolean;

    { Is the move from OldPos to ProposedNewPos possible for me.
      Returns true and sets NewPos if some move is allowed.
      Overloaded version without ProposedNewPos doesn't do wall-sliding,
      and only answers if exactly this move is allowed.

      If this 3D object allows to use sphere as the bounding volume,
      if will be used (see @link(Sphere)).

      This ignores the geometry of this 3D object (to not accidentaly collide
      with your own geometry), and checks collisions with the rest of the world.
      @groupBegin }
    function MoveAllowed(const OldPos, ProposedNewPos: TVector3;
      out NewPos: TVector3;
      const BecauseOfGravity: boolean): boolean; overload;
    function MoveAllowed(const OldPos, NewPos: TVector3;
      const BecauseOfGravity: boolean): boolean; overload;
    { @groupEnd }

    { Cast a ray from myself to the world, see what is hit.

      This ignores the geometry of this 3D object (to not accidentaly collide
      with your own geometry), and checks collisions with the rest of the world. }
    function Ray(const RayOrigin, RayDirection: TVector3): TRayCollision;

    { Is this object's bounding volume (@link(BoundingBox))
      included in parent bounding volume.
      This should be always @true for non-debug scenes.
      Violating this may cause rendering artifacts, things could
      disappear when they should not.
      Using this is reasonable only if you attach a debug geometry
      to your scene, and you don't want to enlarge your bounding volume
      (e.g. because this debug geometry visualizes something determined
      by the bounding volume, and it would create a "feedback loop"
      if the visualization itself would enlarge the bounding box). }
    property InternalExcludeFromParentBoundingVolume: boolean
      read FInternalExcludeFromParentBoundingVolume
      write FInternalExcludeFromParentBoundingVolume;

    { Convert position between local and outside coordinate system.
      This is called OutsideToLocal, not WorldToLocal, because it only handles transformation
      defined in this item --- it does not recursively apply all transform on the way to root
      @groupBegin. }
    function OutsideToLocal(const Pos: TVector3): TVector3;
    function LocalToOutside(const Pos: TVector3): TVector3;
    { @groupEnd }

    { Gravity may make this object fall down (see FallSpeed)
      or grow up (see GrowSpeed). See also PreferredHeight.

      Special notes for TPlayer: player doesn't use this (TPlayer.Gravity
      should remain @false), instead player relies on
      TPlayer.Camera.Gravity = @true, that does a similar thing (with some
      extras, to make camera effects). This will change in the future,
      to merge these two gravity implementations.
      Although the TPlayer.Fall method still works as expected
      (it's linked to TWalkCamera.OnFall in this case).

      TODO: In CGE 6.6 this will be deprecated, and you will be adviced
      to always use physics, through @link(TCastleTransform.RigidBody),
      to have realistic gravity. }
    property Gravity: boolean read FGravity write FGravity default false;

    { Falling speed, in units per second, for @link(Gravity).

      This is relevant only if @link(Gravity) and PreferredHeight <> 0.
      0 means no falling.

      TODO: In CGE 6.6 this will be deprecated, and you will be adviced
      to always use physics, through @link(TCastleTransform.RigidBody),
      to have realistic gravity. }
    property FallSpeed: Single read FFallSpeed write FFallSpeed default 0;

    { Growing (raising from crouching to normal standing position)
      speed, in units per second.
      This is used by non-flying creatures when climbing up stairs,
      in which case @link(Translation) ("legs positon") may be sometimes under
      the ground while Middle ("eyes position") will be always above the ground
      and will try to grow to be at PreferredHeight above the ground.

      This is relevant only if @link(Gravity) and PreferredHeight <> 0.
      0 means no growing. }
    property GrowSpeed: Single read FGrowSpeed write FGrowSpeed default 0;

    { The preferred height of the object @link(Middle) above the ground,
      when the object is standing on the ground firmly.
      This is used by objects affected by gravity (like non-flying creatures
      and items) to know how far they should fall down or grow up.

      The default implementation in this class looks at MiddleHeight property,
      see the algorithm described there.
      This may be dynamic (may change during creature lifetime,
      so you can make the creature duck or grow if you want). }
    function PreferredHeight: Single; virtual;

    { How high are creature eyes in the model.
      Value 0 means that eyes are at the bottom of the model,
      0.5 means the middle, 1 means top.

      The @italic(top) is always considered to be at the top of the bounding box.

      Definition of @italic(bottom) depends on @link(Gravity):

      @unorderedList(
        @item(
          When Gravity is @true, then the @italic(bottom) is considered to be
          the plane where World.GravityCoordinate (like Z or Y axis) is zero.
          The actual bottom (lowest point) of the bounding box doesn't matter.
          This means that things placed below zero plane (like a creature tentacle
          or leg) will sink into the ground, instead of causing whole creature
          to move up. It also means that the creature can easily float above
          the ground, just model it a little above the zero plane.

          In other words, this allows you to model the creature
          with respect to the ground (zero plane), which is comfortable.

          Note that setting MiddleHeight to exact 0 means that gravity will not work,
          as it means that the PreferredHeight above the ground
          is to be stuck right at the ground level.

          For gravity to work right, the MiddleHeight should be large enough
          to cause PreferredHeight to be > @link(Sphere) radius,
          for all possible animation states (for all possible bounding box values).
        )

        @item(
          When Gravity is @false, then the @italic(bottom) is considered
          at the bottom of the bounding box.

          This way it works regardless of where (0,0,0) is in your model
          (regardless if (0,0,0) represents legs, or middle of your creature),
          since we adjust to the BoundingBox position.
        )
      )

      This property determines how the TCastleTransform
      handles the @link(Middle) implementation
      (this is the point used for various collision detection routines)
      and @link(PreferredHeight) (this is the preferred height of @link(Middle)
      above the ground). You can override these two methods to use a different
      approach, and then ignore MiddleHeight completely. }
    property MiddleHeight: Single read FMiddleHeight write FMiddleHeight
      default DefaultMiddleHeight;

    { Transformation (from local to global) as a matrix. }
    function Transform: TMatrix4;

    { Inverse transformation as a matrix, thus transforming from global to local
      coordinate system. }
    function InverseTransform: TMatrix4;

    { Unconditionally move this 3D object by given vector.
      You usually don't want to use this directly, instead use @link(Move)
      method to move checking collisions (and with optional wall sliding). }
    procedure Translate(const T: TVector3);

    { Move, if possible (no collisions). This is the simplest way to move
      a 3D object, and a basic building block for artificial intelligence
      of creatures.

      Checks move possibility by MoveAllowed, using @link(Middle) point.
      Actual move is done using @link(Translate). }
    function Move(const ATranslation: TVector3;
      const BecauseOfGravity: boolean;
      const EnableWallSliding: boolean = true): boolean;

    { Translation (move) the children. Zero by default. }
    property Translation: TVector3 read FTranslation write SetTranslation;

    function GetTranslation: TVector3; deprecated 'use Translation';

    { Center point around which the @link(Rotation) and @link(Scale) is performed. }
    property Center: TVector3 read FCenter write SetCenter;

    { Rotation in 3D, around a specified axis.
      Rotation is expressed as a 4D vector, in which the first 3 components
      specify the rotation axis (does not need to be normalized, but must be non-zero),
      and the last component is the rotation angle @italic(in radians).

      Rotation is done around @link(Center). }
    property Rotation: TVector4 read FRotation write SetRotation;

    { Scale in 3D. Scaling is done around @link(Center)
      and with orientation given by @link(ScaleOrientation).

      We do the best we can to work with @italic(any) scale value,
      even negative or zero. But usually, it's best to keep the scale
      positive. More information:

      @orderedList(
        @item(If you can, keep the scale uniform, that is scale equal amount
          in X, Y and Z. For example set scale = @code((3.0, 3.0, 3.0))
          to scale 3x times, and avoid scale like @code((3.0, 1.0, 1.0))
          that scales more in one direction.

          Non-uniform scale works, but some collisions are not perfectly
          calculated then. (For example, an ideal sphere is no longer a sphere
          when scaled in non-uniform fashion, and not everywhere do we
          account for that.) Although it works Ok on meshes.
          @link(ScaleOrientation) matters in case of non-uniform scale.
        )

        @item(All scale components should > 0 if you want 3D lighting
          to work corrrectly. That is, avoid negative scale, that flips
          the orientation of faces (CCW becomes CW), or standard
          lighting may not work Ok.

          For unlit stuff, or custom lighting, negative scale may be Ok.
          For many 2D games that use no lighting/custom lighting,
          negative scale is Ok.)

        @item(At least, keep all scale components non-zero.
          Otherwise the scaling operation is not invertible,
          and generally collisions will not work correctly.

          If you really need to set zero scale, at least consider
          using @link(Collides) = @false.)
      )
    }
    property Scale: TVector3 read FScale write SetScale;

    { Orientation in which 3D @link(Scale) is performed. }
    property ScaleOrientation: TVector4 read FScaleOrientation write SetScaleOrientation;

    { Make the transform do nothing --- zero @link(Translation), zero @link(Rotation),
      @link(Scale) to one. Also resets @link(ScaleOrientation). }
    procedure Identity;

    { Participate in rigid body physics simulation.
      This makes this object collidable with other rigid bodies
      (if @link(Collides))
      and it allows to move and rotate because of gravity
      or because of collisions with other objects
      (if @link(TRigidBody.Dynamic) is @true).

      Setting this property makes this 3D object
      a single rigid body for the physics engine.

      If this property is assigned and the @link(TRigidBody.Dynamic) is @true
      (and @link(TRigidBody.Dynamic) is @true by default)
      then this object is moved and rotated using the physics engine.
      It will move because of gravity (if @link(TRigidBody.Gravity),
      also @true by default),
      and because of collisions with other objects.

      The @link(TRigidBody.Collider) property must be initialized
      @italic(before) assigning the @link(TRigidBody) instance here.
      So you must create a @link(TCollider) descendant, specyfying the given
      @link(TRigidBody) as a parent.
      A rigid body without a collider would in theory not collide with anything,
      and (if @link(TRigidBody.Dynamic)) would simply fall down because of gravity.
      In practice, a rigid body without a collider is simply not allowed.
      If you really need this, assign anything to @link(TRigidBody.Collider)
      and just set @link(Collides) to @false.

      @bold(Our engine (for now) also has an internal, simple physics simulation,
      used to perform collisions with player, creatures, and optional
      (unrealistic) gravity.)
      So we have two independent physics systems,
      but they try to not get into each others way (they each perform
      a different task).
      In the future there will be an option to use
      the full-featured physics engine for all simulations,
      also for player and creatures, at which point our "internal physics
      simulation" will become deprecated.
      For now, be aware of these:

      @unorderedList(
        @item(@link(TCastleTransform.Collides) property affects @italic(both our
          "simple physics simulation" and the "full-featured physics engine").
          It determines whether the object is collidable.
        )

        @item(@link(TCastleTransform.Gravity) property @italic(only affects the
          "simple physics simulation"). It is by default @false.

          It has no effect on the "full-featured physics engine" behaviour,
          that has an independent property @link(TRigidBody.Gravity),
          which is @true by default.

          You should not set both @link(TCastleTransform.Gravity) to @true
          and @link(TRigidBody.Gravity) to @true, it would mean that
          @italic(gravity simulation is performed twice).
          In the future, @link(TCastleTransform.Gravity) may be removed
          (or merged with @link(TRigidBody.Gravity), but then old games
          may by surprised by a new default @true.)
        )

        @item(The collider used by our internal, simple physics is independent
          from the @link(TRigidBody.Collider).
          The internal, simple physics uses colliders implicitly implemented
          in the overridden @link(TCastleTransform.HeightCollision),
          @link(TCastleTransform.MoveCollision) and friends.
          In case of @link(TCastleSceneCore), the rule is simple:

          @unorderedList(
            @item(If the @link(TCastleSceneCore.Spatial) contains
              ssDynamicCollisions or ssStaticCollisions, then the object collides
              as a mesh. This makes precise collisions with all the triangles.
              Any mesh, convex or concave, is correctly solved.)
            @item(Otherwise, the object collides as it's axis-aligned bounding box.)
          )
        )
      )

      Note that an object can only be present once in the @link(World)
      to be a rigid body. Breaking this rule will cause the
      @link(EMultipleReferencesInWorld) exception at an undefined time.
    }
    property RigidBody: TRigidBody read FRigidBody write SetRigidBody;

    property Position: TVector3 read FTranslation write SetTranslation;
      deprecated 'use Translation';

    { Direction the creature is facing, and up vector.
      These properties provide an alternative way to get and set the @link(Rotation)
      of the transformation.
      Thinking in terms of "direction" and "up" is often more natural
      when transforming creatures and player.

      The @link(Orientation) determines what is your default direction and up
      (when the @link(Rotation) is zero).
      By default we follow X3D standard vectors suitable for gravity along
      the Y axis. So direction is -Z (DefaultCameraDirection),
      up is +Y (DefaultCameraUp).

      The @link(Direction) and @link(Up) vectors should always be normalized
      (have length 1). When setting them by these properties, we will normalize
      them automatically.

      They must also always be orthogonal.
      When setting @link(Direction), @link(Up) will always be automatically
      adjusted to be orthogonal to @link(Direction). And vice versa ---
      when setting @link(Up), @link(Direction) will be adjusted.

      @groupBegin }
    property Direction: TVector3 read GetDirection write SetDirection;
    property Up: TVector3 read GetUp write SetUp;
    { @groupEnd }

    { Get at once vectors: position, direction, up. }
    procedure GetView(out APos, ADir, AUp: TVector3);

    { Set at once vectors: position, direction, up.

      ADir and AUp given here do not have to be normalized
      (they will be normalized if needed).
      They will be automatically fixed to be orthogonal, if necessary:
      when AdjustUp = @true (the default) we will adjust the up vector
      (preserving the given direction value),
      otherwise we will adjust the direction (preserving the given up value). }
    procedure SetView(const APos, ADir, AUp: TVector3;
      const AdjustUp: boolean = true); overload;
    procedure SetView(const ADir, AUp: TVector3;
      const AdjustUp: boolean = true); overload;

    { Change up vector, keeping the direction unchanged.
      If necessary, the up vector provided here will be fixed to be orthogonal
      to direction.

      This is similar to assigning @link(Up) vector using it's property setter,
      but different behavior happens when we need to fix vectors to have
      direction orthogonal to up (which must be always true).
      In case of assigning @link(Up) by property setter,
      the @link(Direction) vector is changed (if necessary, to be orthogonal to up).
      In case of this method, the up vector is changed (if necessary,
      to be orthogonal to direction).

      It's good to use this if you have a preferred up vector for creatures,
      but still preserving the direction vector has the highest priority. }
    procedure UpPrefer(const AUp: TVector3);

    { How the direction and up vectors determine transformation.
      See TOrientationType for values documentation.

      The default value of this is determined by static variable
      DefaultOrientation, this is usually comfortable (because almost
      always you use the same Orientation throughout your game).
      By default it's otUpYDirectionMinusZ (matching default cameras
      of OpenGL and VRML/X3D).

      This value determines how you should model your 3D models,
      like the creatures, the items, and the player weapons.
      Generally, it applies to every 3D model that is used as
      a child of this TCastleTransform instance. }
    property Orientation: TOrientationType read FOrientation write FOrientation;
  published
    { 3D objects inside.
      Freeing these items automatically removes them from this list. }
    property List: TCastleTransformList read FList;

    { If this 3D object is rendered as part of TCastleSceneManager,
      and @link(TCastleAbstractViewport.UseGlobalLights) is @true, then this property allows
      to make an exception for this 3D object: even though
      @link(TCastleAbstractViewport.UseGlobalLights) is @true,
      do not use global lights @italic(for this 3D object).

      Note that this is not applied recursively. Instead, it is checked at each TCastleTransform instance
      that checks TRenderParams.BaseLights. In practice, it is only checked at TCastleScene,
      unless you do custom rendering on your own. }
    property ExcludeFromGlobalLights: boolean
      read FExcludeFromGlobalLights write FExcludeFromGlobalLights default false;

    { Exclude from rendering statistics in
      @link(TCastleAbstractViewport.Statistics). }
    property ExcludeFromStatistics: boolean
      read FExcludeFromStatistics write FExcludeFromStatistics default false;
  end;

  { 3D world. List of 3D objects, with some central properties. }
  TSceneManagerWorld = class(TCastleTransform)
  private
    FKraftEngine: TKraft;
    WasPhysicsStep: boolean;
    TimeAccumulator: TFloatTime;
    FCameraWorldPosition, FCameraWorldDirection, FCameraWorldUp: TVector3;
    FCameraViewKnown: boolean;
    { Create FKraftEngine, if not assigned yet. }
    procedure InitializePhysicsEngine;
  public
    OnCursorChange: TNotifyEvent;
    OnVisibleChange: TVisibleChangeEvent;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { See TCastleSceneManager.CollisionIgnoreItem. }
    function CollisionIgnoreItem(const Sender: TObject;
      const Triangle: PTriangle): boolean; virtual; abstract;
    { Up vector, according to gravity. Gravity force pulls in -GravityUp direction. }
    function GravityUp: TVector3; virtual; abstract;
    { The major axis of gravity vector: 0, 1 or 2.
      This is derived from GravityUp value. It can only truly express
      GravityUp vector values (1,0,0) or (0,1,0) or (0,0,1),
      although in practice this is enough for normal games (normal 3D scenes
      use up either +Y or +Z).

      We try to avoid using it in
      the engine, and use full GravityUp vector wherever possible.
      Full GravityUp vector may allow for more fun with weird gravity
      in future games. }
    function GravityCoordinate: Integer;
    { Player, see TCastleSceneManager.Player. }
    function Player: TCastleTransform; virtual; abstract;
    { Parameters to prepare rendering for,
      see @link(TCastleAbstractViewport.PrepareParams). }
    function PrepareParams: TPrepareParams; virtual; abstract;
    { Sectors in the world, for AI. See TCastleSceneManager.Sectors. }
    function Sectors: TSectorList; virtual; abstract;
    { Water volume. See TCastleSceneManager.Water. }
    function Water: TBox3D; virtual; abstract;

    { Collisions with world. They call corresponding methods without the World
      prefix, automatically taking into account some knowledge about this
      3D world.

      Calling these methods to check collisions makes sense if your
      collision query is not initiated by any existing TCastleTransform instance.

      If your query originates from some existing TCastleTransform instance,
      you usually do not want to call these WorldXxx methods.
      Instead call TCastleTransform.MoveAllowed, TCastleTransform.Height methods.
      Underneath, they still call @code(World.WorldMoveAllowed) and
      @code(World.WorldHeight),
      additionally making sure that the 3D object does not collide with itself.
      @groupBegin }
    function WorldMoveAllowed(
      const OldPos, ProposedNewPos: TVector3; out NewPos: TVector3;
      const IsRadius: boolean; const Radius: Single;
      const OldBox, NewBox: TBox3D;
      const BecauseOfGravity: boolean): boolean; overload; virtual; abstract;
    function WorldMoveAllowed(
      const OldPos, NewPos: TVector3;
      const IsRadius: boolean; const Radius: Single;
      const OldBox, NewBox: TBox3D;
      const BecauseOfGravity: boolean): boolean; overload; virtual; abstract;
    function WorldHeight(const APosition: TVector3;
      out AboveHeight: Single; out AboveGround: PTriangle): boolean; virtual; abstract;
    function WorldLineOfSight(const Pos1, Pos2: TVector3): boolean; virtual; abstract;
    function WorldRay(const RayOrigin, RayDirection: TVector3): TRayCollision; virtual; abstract;
    function WorldBoxCollision(const Box: TBox3D): boolean;
    function WorldSphereCollision(const Pos: TVector3; const Radius: Single): boolean;
    function WorldSphereCollision2D(const Pos: TVector2; const Radius: Single;
      const Details: TCollisionDetails = nil): boolean;
    function WorldPointCollision2D(const Point: TVector2): boolean;
    { @groupEnd }

    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;

    { Last known camera position, direction and up.
      Consistent with @link(TCastleScene) properties of the same name.
      @groupBegin }
    property CameraWorldPosition: TVector3 read FCameraWorldPosition;
    property CameraWorldDirection: TVector3 read FCameraWorldDirection;
    property CameraWorldUp: TVector3 read FCameraWorldUp;
    property CameraViewKnown: boolean read FCameraViewKnown;
    { @groupEnd }

    procedure CameraChanged(ACamera: TCamera); override;
  end;

  {$define read_interface}
  {$I castletransform_physics.inc}
  {$undef read_interface}

{ Apply transformation to a matrix.
  Calculates at the same time transformation matrix, and it's inverse,
  and multiplies given Transform, InverseTransform appropriately.
  The precise meaning of Center, Translation and such parameters
  follows exactly the X3D Transform node definition (see
  http://www.web3d.org/files/specifications/19775-1/V3.2/Part01/components/group.html#Transform ).

  @param(Rotation Rotation is expressed as a 4D vector,
    in which the first 3 components
    specify the rotation axis (does not need to be normalized, but must be non-zero),
    and the last component is the rotation angle @italic(in radians).)
}
procedure TransformMatricesMult(var Transform, InverseTransform: TMatrix4;
  const Center: TVector3;
  const Rotation: TVector4;
  const Scale: TVector3;
  const ScaleOrientation: TVector4;
  const Translation: TVector3);

implementation

uses CastleLog;

{$define read_implementation}
{$I castletransform_physics.inc}
{$I castletransform_collisions.inc}
{$undef read_implementation}

{ TransformMatricesMult ------------------------------------------------------ }

procedure TransformMatricesMult(var Transform, InverseTransform: TMatrix4;
  const Center: TVector3;
  const Rotation: TVector4;
  const Scale: TVector3;
  const ScaleOrientation: TVector4;
  const Translation: TVector3);
var
  M, IM: TMatrix4;
  MRotateScaleOrient, IMRotateScaleOrient: TMatrix4;
begin
  { To make InverseTransform, we multiply inverted matrices in inverted order
    below. }

  MultMatricesTranslation(Transform, InverseTransform, Translation + Center);

  { We avoid using RotationMatricesRad when angle = 0, since this
    is often the case, and it makes TransformState much faster
    (which is important --- TransformState is important for traversing state). }
  if Rotation[3] <> 0 then
  begin
    { Note that even rotation Axis = zero is OK, both M and IM will be
      identity in this case. }
    RotationMatricesRad(Rotation, M, IM);
    Transform := Transform * M;
    InverseTransform := IM * InverseTransform;
  end;

  if (Scale[0] <> 1) or
     (Scale[1] <> 1) or
     (Scale[2] <> 1) then
  begin
    if ScaleOrientation[3] <> 0 then
    begin
      RotationMatricesRad(ScaleOrientation, MRotateScaleOrient, IMRotateScaleOrient);
      Transform := Transform * MRotateScaleOrient;
      InverseTransform := IMRotateScaleOrient * InverseTransform;
    end;

    { For scaling, we explicitly request that if ScalingFactor contains
      zero, IM will be forced to be identity (the 2nd param to ScalingMatrices
      is "true"). That's because X3D allows
      scaling factor to have 0 components (we need InverseTransform only
      for special tricks). }

    ScalingMatrices(Scale, true, M, IM);
    Transform := Transform * M;
    InverseTransform := IM * InverseTransform;

    if ScaleOrientation[3] <> 0 then
    begin
      { That's right, we reuse MRotateScaleOrient and IMRotateScaleOrient
        matrices below. Since we want to reverse them now, so normal
        Transform is multiplied by IM and InverseTransform is multiplied by M. }
      Transform := Transform * IMRotateScaleOrient;
      InverseTransform := MRotateScaleOrient * InverseTransform;
    end;
  end;

  MultMatricesTranslation(Transform, InverseTransform, -Center);
end;

{ TRayCollision --------------------------------------------------------------- }

function TRayCollision.IndexOfItem(const Item: TCastleTransform): Integer;
begin
  for Result := 0 to Count - 1 do
    if List^[Result].Item = Item then Exit;
  Result := -1;
end;

function TRayCollision.IndexOfItem(const ItemClass: TCastleTransformClass): Integer;
begin
  for Result := 0 to Count - 1 do
    if List^[Result].Item is ItemClass then Exit;
  Result := -1;
end;

{ TCollisionDetails ------------------------------------------------------------ }

function TCollisionDetails.IndexOfItem(const Item: TCastleTransform): Integer;
begin
  for Result := 0 to Count - 1 do
    if List^[Result].Item = Item then Exit;
  Result := -1;
end;

procedure TCollisionDetails.Add(const Item: TCastleTransform);
var
  NewItem: PCollisionDetailsItem;
begin
  NewItem := inherited Add();
  NewItem^.Item := Item;
end;

{ TRenderParams -------------------------------------------------------------- }

constructor TRenderParams.Create;
begin
  inherited;
  RenderTransform := TMatrix4.Identity;
  RenderTransformIdentity := true;
end;

{ TCastleTransformList ------------------------------------------------------------ }

constructor TCastleTransformList.Create(const FreeObjects: boolean; const AOwner: TCastleTransform);
begin
  inherited Create(FreeObjects);
  FOwner := AOwner;
end;

procedure TCastleTransformList.Notify(Ptr: Pointer; Action: TListNotification);
var
  B: TCastleTransform;
begin
  inherited;

  if Owner <> nil then
  begin
    B := TCastleTransform(Ptr);

    case Action of
      lnAdded:
        begin
          if Owner.World <> nil then
            B.AddToWorld(Owner.World);
          { Register Owner to be notified of item destruction. }
          B.FreeNotification(Owner);
        end;
      lnExtracted, lnDeleted:
        begin
          if (Owner.World <> nil) and
             { It is possible that "B.World <> Owner.World" when B is getting
               freed and has World set to nil in constructor already. }
             (B.World = Owner.World) then
            B.RemoveFromWorld(Owner.World);
          { Do not call RemoveFreeNotification when Owner is equal to B.World,
            this would prevent getting notification when to nil FWorld in
            TCastleTransform.Notification. }
          if B.World <> Owner then
            B.RemoveFreeNotification(Owner);
        end;
      else raise EInternalError.Create('TCastleTransformList.Notify action?');
    end;

    if (Owner.World <> nil) and Assigned(Owner.World.OnCursorChange) then
      Owner.World.OnCursorChange(Owner);
  end;
end;

function TCastleTransformList.GetItem(const I: Integer): TCastleTransform;
begin
  Result := TCastleTransform(inherited Items[I]);
end;

procedure TCastleTransformList.SetItem(const I: Integer; const Item: TCastleTransform);
begin
  inherited Items[I] := Item;
end;

function TCastleTransformList.First: TCastleTransform;
begin
  Result := (inherited First) as TCastleTransform;
end;

function TCastleTransformList.Last: TCastleTransform;
begin
  Result := (inherited Last) as TCastleTransform;
end;

{ TCastleTransform ---------------------------------------------------------------- }

const
  NoScale: TVector3 = (Data: (1, 1, 1));

constructor TCastleTransform.Create(AOwner: TComponent);
begin
  inherited;
  FCastShadowVolumes := true;
  FExists := true;
  FCollides := true;
  FPickable := true;
  FVisible := true;
  FCursor := mcDefault;
  FList := TCastleTransformList.Create(false, Self);
  FMiddleHeight := DefaultMiddleHeight;
  FOnlyTranslation := true;
  FScale := NoScale;
  FOrientation := DefaultOrientation;
end;

destructor TCastleTransform.Destroy;
begin
  PhysicsDestroy;
  FreeAndNil(FList);
  { set to nil, to detach free notification }
  ChangeWorld(nil);
  GLContextClose;
  inherited;
end;

procedure TCastleTransform.VisibleChangeHere(const Changes: TVisibleChanges);
begin
  if (World <> nil) and Assigned(World.OnVisibleChange) then
    World.OnVisibleChange(Self, Changes);
end;

procedure TCastleTransform.SetCursor(const Value: TMouseCursor);
begin
  if FCursor <> Value then
  begin
    FCursor := Value;
    if (World <> nil) and Assigned(World.OnCursorChange) then
      World.OnCursorChange(Self);
  end;
end;

function TCastleTransform.GetExists: boolean;
begin
  Result := FExists and (Disabled = 0);
end;

function TCastleTransform.GetCollides: boolean;
begin
  Result := FCollides and GetExists;
end;

function TCastleTransform.GetPickable: boolean;
begin
  Result := FPickable and GetExists;
end;

function TCastleTransform.GetVisible: boolean;
begin
  Result := FVisible and GetExists;
end;

function TCastleTransform.Sector: TSector;
begin
  if (World <> nil) and (World.Sectors <> nil) then
    Result := World.Sectors.SectorWithPoint(Middle) else
    Result := nil;
end;

function TCastleTransform.Sphere(out Radius: Single): boolean;
begin
  Result := false;
  Radius := 0;
end;

procedure TCastleTransform.Disable;
begin
  Inc(Disabled);
end;

procedure TCastleTransform.Enable;
begin
  Dec(Disabled);
end;

procedure TCastleTransform.AddToWorld(const Value: TSceneManagerWorld);
var
  I: Integer;
begin
  Assert(Value <> nil);
  if FWorld <> Value then
  begin
    if FWorld <> nil then
      raise ECannotAddToAnotherWorld.Create('Cannot add object existing in one world to another. This means that your object is part of SceneManager1.Items, and you are adding it to SceneManager2.Items. You have to remove it from SceneManager1.Items first.');
    ChangeWorld(Value);
  end else
    Inc(FWorldReferences);

  // list stuff
  if FList <> nil then // when one list is within another, this may be called during own destruction by TCastleTransformList.Notify
    for I := 0 to List.Count - 1 do
      List[I].AddToWorld(Value);
end;

procedure TCastleTransform.RemoveFromWorld(const Value: TSceneManagerWorld);
var
  I: Integer;
begin
  Assert(Value <> nil);
  Assert(FWorldReferences > 0);
  if FWorld <> Value then
    WritelnWarning('TCastleTransform.RemoveFromWorld: Removing from World you were not part of. This probably means that you placed one TCastleTransform instance in multiple worlds (multiple TCastleSceneManagers) at the same time, which is not allowed. Always remove 3D object from previous scene manager (e.g. by "SceneManger.Items.Remove(xxx)") before adding to new scene manager.');

  Dec(FWorldReferences);
  if FWorldReferences = 0 then
    ChangeWorld(nil);

  // list stuff
  if FList <> nil then // when one list is within another, this may be called during own destruction by TCastleTransformList.Notify
    for I := 0 to List.Count - 1 do
      List[I].RemoveFromWorld(Value);
end;

procedure TCastleTransform.ChangeWorld(const Value: TSceneManagerWorld);
begin
  if FWorld <> Value then
  begin
    if FWorld <> nil then
    begin
      PhysicsChangeWorldDetach;

      { Do not call RemoveFreeNotification when FWorld is also our list owner,
        this would prevent getting notification in TCastleTransform.Notification. }
      if (FWorld.List = nil) or (FWorld.List.IndexOf(Self) = -1) then
        FWorld.RemoveFreeNotification(Self);
    end;

    FWorld := Value;
    FWorldReferences := Iff(Value <> nil, 1, 0);

    if FWorld <> nil then
    begin
      // Ignore FWorld = Self case, when this is done by TSceneManagerWorld.Create? No need to.
      //if FWorld <> Self then
      FWorld.FreeNotification(Self);

      PhysicsChangeWorldAttach;
    end;
  end;
end;

procedure TCastleTransform.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;

  { make sure to nil FWorld reference }
  if (Operation = opRemove) and (AComponent = FWorld) then
    ChangeWorld(nil);

  { We have to remove a reference to the object from the List.
    This is crucial: TCastleTransformList.Notify,
    and e.g. GLContextClose call, assume that all objects on
    the List are always valid objects (no invalid references,
    even for a short time). }

  { About List <> nil check:

    How situation with List = nil may happen? When our List is destroyed,
    it calls B.FreeNotification on all it's items, so it (falsely) seems we will
    not get any more notifications.

    It turns out that we may get notifications,
    and they are notifications about our own destruction (AComponent = Self).
    That is because TComponent.Notification passes down the notification to
    all it's FComponents, that is rtl/objpas/classes/compon.inc
    (in FPC sources) contains code

    Procedure TComponent.Notification(AComponent: TComponent; Operation: TOperation);
    begin
      ...
      For Runner:=0 To FComponents.Count-1 do
        TComponent(FComponents.Items[Runner]).Notification(AComponent,Operation);
    end;

    And FComponents contain all components that are owned.
    So we are informed when something is removed from the owner,
    including about our own removal. (And in this case, we are a TCastleTransform descendant
    ourselves, just like our children; so check "AComponent is TCastleTransform" doesn't
    protect us.)
    Practical situation when it happens is in testcases
    TTestCastleTransform.TestNotifications and TTestCastleTransform.TestNotificationsSceneManager. }

  if (Operation = opRemove) and (AComponent is TCastleTransform) and (List <> nil) then
    List.RemoveAll(AComponent);

  PhysicsNotification(AComponent, Operation);
end;

function TCastleTransform.Height(const MyPosition: TVector3;
  out AboveHeight: Single): boolean;
var
  AboveGroundIgnored: PTriangle;
begin
  Result := Height(MyPosition, AboveHeight, AboveGroundIgnored);
end;

function TCastleTransform.Height(const MyPosition: TVector3;
  out AboveHeight: Single; out AboveGround: PTriangle): boolean;
begin
  Disable;
  try
    Result := World.WorldHeight(MyPosition, AboveHeight, AboveGround);
  finally Enable end;
end;

function TCastleTransform.LineOfSight(const Pos1, Pos2: TVector3): boolean;
begin
  Disable;
  try
    Result := World.WorldLineOfSight(Pos1, Pos2);
  finally Enable end;
end;

function TCastleTransform.MoveAllowed(
  const OldPos, ProposedNewPos: TVector3;
  out NewPos: TVector3;
  const BecauseOfGravity: boolean): boolean;
var
  Sp: boolean;
  SpRadius: Single;
  OldBox, NewBox: TBox3D;
begin
  { save bounding volume information before calling Disable, as Disable makes
    bounding volume empty }
  Sp := Sphere(SpRadius);
  if not Sp then
    SpRadius := 0; { something predictable, for safety }
  OldBox := BoundingBox;
  NewBox := OldBox.Translate(ProposedNewPos - OldPos);

  Disable;
  try
    Result := World.WorldMoveAllowed(OldPos, ProposedNewPos, NewPos,
      Sp, SpRadius, OldBox, NewBox, BecauseOfGravity);
  finally Enable end;
end;

function TCastleTransform.MoveAllowed(
  const OldPos, NewPos: TVector3;
  const BecauseOfGravity: boolean): boolean;
var
  Sp: boolean;
  SpRadius: Single;
  OldBox, NewBox: TBox3D;
begin
  { save bounding volume information before calling Disable, as Disable makes
    bounding volume empty }
  Sp := Sphere(SpRadius);
  if not Sp then
    SpRadius := 0; { something predictable, for safety }
  OldBox := BoundingBox;
  NewBox := OldBox.Translate(NewPos - OldPos);

  Disable;
  try
    Result := World.WorldMoveAllowed(OldPos, NewPos,
      Sp, SpRadius, OldBox, NewBox, BecauseOfGravity);
  finally Enable end;
end;

function TCastleTransform.Ray(
  const RayOrigin, RayDirection: TVector3): TRayCollision;
begin
  Disable;
  try
    Result := World.WorldRay(RayOrigin, RayDirection);
  finally Enable end;
end;

{ list stuff ---------------------------------------------------------------- }

procedure TCastleTransform.Add(const Item: TCastleTransform);
begin
  List.Add(Item);
end;

procedure TCastleTransform.Insert(const Index: Integer; const Item: TCastleTransform);
begin
  List.Insert(Index, Item);
end;

function TCastleTransform.GetItem(const I: Integer): TCastleTransform;
begin
  Result := List[I];
end;

procedure TCastleTransform.SetItem(const I: Integer; const Item: TCastleTransform);
begin
  List[I] := Item;
end;

function TCastleTransform.Count: Integer;
begin
  Result := List.Count;
end;

procedure TCastleTransform.Remove(const Item: TCastleTransform);
begin
  List.Remove(Item);
end;

procedure TCastleTransform.Clear;
begin
  List.Clear;
end;

procedure TCastleTransform.Exchange(const Index1, Index2: Integer);
begin
  List.Exchange(Index1, Index2);
end;

function CompareBackToFront2D(A, B: Pointer): Integer;
begin
  Result := TBox3D.CompareBackToFront2D(TCastleTransform(A).BoundingBox, TCastleTransform(B).BoundingBox);
end;

var
  { Has to be global, since TObjectList.Sort
    requires normal function (not "of object"). }
  SortCameraPosition: TVector3;

function CompareBackToFront3D(A, B: Pointer): Integer;
begin
  Result := TBox3D.CompareBackToFront3D(TCastleTransform(A).BoundingBox, TCastleTransform(B).BoundingBox,
    SortCameraPosition);
end;

procedure TCastleTransform.SortBackToFront(const BlendingSort: TBlendingSort;
  const CameraPosition: TVector3);
begin
  case BlendingSort of
    bs2D: List.Sort(@CompareBackToFront2D);
    bs3D:
      begin
        SortCameraPosition := CameraPosition;
        List.Sort(@CompareBackToFront3D);
      end;
  end;
end;

procedure TCastleTransform.SortBackToFront2D;
begin
  SortBackToFront(bs2D, TVector3.Zero);
end;

function TCastleTransform.LocalBoundingBox: TBox3D;
var
  I: Integer;
begin
  Result := TBox3D.Empty;
  if GetExists then
  begin
    for I := 0 to List.Count - 1 do
      if not List[I].InternalExcludeFromParentBoundingVolume then
        Result.Include(List[I].BoundingBox);
  end;
end;

procedure TCastleTransform.LocalRender(const Frustum: TFrustum; const Params: TRenderParams);
var
  I: Integer;
begin
  if GetVisible then
  begin
    for I := 0 to List.Count - 1 do
      List[I].Render(Frustum, Params);
  end;
end;

procedure TCastleTransform.LocalRenderShadowVolume(
  ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
  const ParentTransformIsIdentity: boolean;
  const ParentTransform: TMatrix4);
var
  I: Integer;
begin
  if GetExists and CastShadowVolumes then
  begin
    for I := 0 to List.Count - 1 do
      List[I].RenderShadowVolume(ShadowVolumeRenderer,
        ParentTransformIsIdentity, ParentTransform);
  end;
end;

procedure TCastleTransform.PrepareResources(const Options: TPrepareResourcesOptions;
  const ProgressStep: boolean; const Params: TPrepareParams);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do
    List[I].PrepareResources(Options, ProgressStep, Params);
end;

function TCastleTransform.PrepareResourcesSteps: Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to List.Count - 1 do
    Result := Result + List[I].PrepareResourcesSteps;
end;

function TCastleTransform.Press(const Event: TInputPressRelease): boolean;
var
  I: Integer;
begin
  Result := false;
  if not GetExists then Exit;

  for I := 0 to List.Count - 1 do
    if List[I].Press(Event) then Exit(true);
end;

function TCastleTransform.Release(const Event: TInputPressRelease): boolean;
var
  I: Integer;
begin
  Result := false;
  if not GetExists then Exit;

  for I := 0 to List.Count - 1 do
    if List[I].Release(Event) then Exit(true);
end;

function TCastleTransform.PointingDeviceActivate(const Active: boolean;
  const Distance: Single; const CancelAction: boolean): boolean;
begin
  { This event is not automatically passed to all children on List,
    instead the TCastleSceneManager has special logic which
    TCastleTransform instances receive the PointingDeviceActivate call. }
  Result := false;
end;

function TCastleTransform.PointingDeviceMove(const Pick: TRayCollisionNode;
  const Distance: Single): boolean;
begin
  { This event is not automatically passed to all children on List,
    instead the TCastleSceneManager has special logic which
    TCastleTransform instances receive the PointingDeviceMove call. }
  Result := false;
end;

procedure TCastleTransform.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  I: Integer;
  Item: TCastleTransform;
  RemoveItem: TRemoveType;
begin
  if GetExists then
  begin
    I := 0;
    while I < List.Count do
    begin
      Item := List[I];
      RemoveItem := rtNone;
      Item.Update(SecondsPassed, RemoveItem);
      if RemoveItem in [rtRemove, rtRemoveAndFree] then
      begin
        List.Delete(I);
        if RemoveItem = rtRemoveAndFree then
          FreeAndNil(Item);
      end else
        Inc(I);
    end;

    UpdateSimpleGravity(SecondsPassed);
    UpdatePhysicsEngine(SecondsPassed);
  end;
end;

procedure TCastleTransform.GLContextClose;
var
  I: Integer;
begin
  { this is called from inherited destructor, so check <> nil carefully }
  if FList <> nil then
  begin
    for I := 0 to List.Count - 1 do
      List[I].GLContextClose;
  end;
end;

procedure TCastleTransform.UpdateGeneratedTextures(
  const RenderFunc: TRenderFromViewFunction;
  const ProjectionNear, ProjectionFar: Single;
  const OriginalViewport: TRectangle);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do
    List[I].UpdateGeneratedTextures(RenderFunc, ProjectionNear, ProjectionFar,
      OriginalViewport);
end;

procedure TCastleTransform.VisibleChangeNotification(const Changes: TVisibleChanges);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do
    List[I].VisibleChangeNotification(Changes);
end;

procedure TCastleTransform.CameraChanged(ACamera: TCamera);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do
    List[I].CameraChanged(ACamera);
end;

function TCastleTransform.Dragging: boolean;
var
  I: Integer;
begin
  Result := false;

  for I := 0 to List.Count - 1 do
  begin
    Result := List[I].Dragging;
    if Result then Exit;
  end;
end;

{ transform stuff -------------------------------------------------------- }

function TCastleTransform.Translation2D: TVector2;
begin
  Result := Translation.XY;
end;

function TCastleTransform.Transform: TMatrix4;
var
  Dummy: TMatrix4;
begin
  TransformMatrices(Result, Dummy); // TODO: optimize, if needed?
end;

function TCastleTransform.InverseTransform: TMatrix4;
var
  Dummy: TMatrix4;
begin
  TransformMatrices(Dummy, Result); // TODO: optimize, if needed?
end;

procedure TCastleTransform.TransformMatricesMult(
  var M, MInverse: TMatrix4);

{$if defined(VER3_0) and defined(DARWIN) and defined(CPUARM64)}
  type
    TTransformData = record
      Transform, InverseTransform: TMatrix4;
      Center: TVector3;
      Rotation: TVector4;
      Scale: TVector3;
      ScaleOrientation: TVector4;
      Translation: TVector3;
    end;

  procedure TransformMatricesMultWorkaround(var TransformData: TTransformData);
  begin
    CastleTransform.TransformMatricesMult(
      TransformData.Transform,
      TransformData.InverseTransform,
      TransformData.Center,
      TransformData.Rotation,
      TransformData.Scale,
      TransformData.ScaleOrientation,
      TransformData.Translation);
  end;

var
  TransformData: TTransformData;
begin
  TransformData.Transform := M;
  TransformData.InverseTransform := MInverse;
  TransformData.Center := FCenter;
  TransformData.Rotation := FRotation;
  TransformData.Scale := FScale;
  TransformData.ScaleOrientation := FScaleOrientation;
  TransformData.Translation := FTranslation;

  // Doing it like this avoids
  // Fatal: Internal error 2014121702
  // from FPC 3.0.3 for 64-bit iPhone (Darwin for AArch64)
  TransformMatricesMultWorkaround(TransformData);

  M := TransformData.Transform;
  MInverse := TransformData.InverseTransform;
{$else}
begin
  CastleTransform.TransformMatricesMult(M, MInverse,
    FCenter, FRotation, FScale, FScaleOrientation, FTranslation);
{$endif}
end;

procedure TCastleTransform.TransformMatrices(
  out M, MInverse: TMatrix4);
begin
  M := TMatrix4.Identity;
  MInverse := TMatrix4.Identity;
  TransformMatricesMult(M, MInverse); // TODO: optimize, if needed?
end;

function TCastleTransform.AverageScale: Single;
begin
  Result := Approximate3DScale(Scale);
end;

function TCastleTransform.AverageScale2D: Single;
begin
  Result := Approximate2DScale(Scale.XY);
end;

{ We assume in all methods below that FOnlyTranslation is the most common case,
  and then that Translation = 0,0,0 is the most common case.
  This is true for many 3D objects. And for only translation,
  we can calculate result much faster (and for translation = zero,
  we don't have to do anything besides calling inherited).

  For some simplest operations, we do not check for Translation = 0,0,0
  case --- if applying Translation is very fast, then checking for
  zero translation would be a waste of time. }

function TCastleTransform.BoundingBox: TBox3D;
begin
  if FOnlyTranslation then
    Result := LocalBoundingBox.Translate(Translation)
  else
    Result := LocalBoundingBox.Transform(Transform);
end;

procedure TCastleTransform.Render(const Frustum: TFrustum; const Params: TRenderParams);
var
  T: TVector3;
  OldRenderTransform, Inverse: TMatrix4;
  OldRenderTransformIdentity: boolean;
begin
  T := Translation;
  if FOnlyTranslation and T.IsZero then
    LocalRender(Frustum, Params)
  else
  begin
    { LocalRender expects Frustum in local coordinates (without
      transformation), so we subtract transformation here. }

    OldRenderTransform         := Params.RenderTransform;
    OldRenderTransformIdentity := Params.RenderTransformIdentity;
    Params.RenderTransformIdentity := false;

    if FOnlyTranslation then
    begin
      MultMatrixTranslation(Params.RenderTransform, T);
      LocalRender(Frustum.Move(-T), Params);
    end else
    begin
      Inverse := TMatrix4.Identity;
      TransformMatricesMult(Params.RenderTransform, Inverse);
      if IsNan(Inverse.Data[0, 0]) then
        {$ifndef VER3_1}
        WritelnWarning('Transform', Format(
          'Inverse transform matrix has NaN value inside:' + NL +
          '%s' + NL +
          '  Matrix source: Center %s, Rotation %s, Scale %s, ScaleOrientation %s, Translation %s',
          [Inverse.ToString('  '),
           FCenter.ToString,
           FRotation.ToString,
           FScale.ToString,
           FScaleOrientation.ToString,
           FTranslation.ToString
          ]));
        {$else}
        { Workaround FPC 3.1.1 Internal error 200211262 when compiling above }
        WritelnWarning('Transform', 'Inverse transform matrix has NaN value inside');
        {$endif}
      LocalRender(Frustum.Transform(Inverse), Params);
    end;

    Params.RenderTransform         := OldRenderTransform;
    Params.RenderTransformIdentity := OldRenderTransformIdentity;
  end;
end;

procedure TCastleTransform.RenderShadowVolume(
  ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
  const ParentTransformIsIdentity: boolean;
  const ParentTransform: TMatrix4);
var
  T: TVector3;
begin
  if FOnlyTranslation then
  begin
    T := Translation;
    if T.IsZero then
      LocalRenderShadowVolume(ShadowVolumeRenderer,
        ParentTransformIsIdentity, ParentTransform)
    else
      LocalRenderShadowVolume(ShadowVolumeRenderer,
        false, TranslationMatrix(T) * ParentTransform);
  end else
    LocalRenderShadowVolume(ShadowVolumeRenderer,
      false, Transform * ParentTransform);
end;

function Bottom(const Gravity: boolean; const GravityCoordinate: Integer;
  const BoundingBox: TBox3D): Single;
begin
  if Gravity then
    Result := 0 else
    Result := BoundingBox.Data[0].Data[GravityCoordinate];
end;

function TCastleTransform.Middle: TVector3;
var
  GC: Integer;
  B: TBox3D;
begin
  GC := World.GravityCoordinate;
  if MiddleForceBox then
    B := MiddleForceBoxValue else
    B := LocalBoundingBox;

  { More correct version would be to take B bottom point, add PreferredHeight,
    and transform this point just like TCastleTransform transforms everything
    else. Optimized implementation below assumes that instead
    of transforming we can add Translation, so we assume that
    transformations do not change this middle point
    (which is Ok if you think e.g. about a non-flying creature that,
    besides moving, only rotates around it's own up axis). }

  Result := Translation;
  Result.Data[GC] := Result.Data[GC] + (Bottom(Gravity, GC, B) + PreferredHeight);
end;

function TCastleTransform.PreferredHeight: Single;
var
  GC: Integer;
  B: TBox3D;
  { $define CHECK_HEIGHT_VS_RADIUS}
  {$ifdef CHECK_HEIGHT_VS_RADIUS} R: Single; {$endif}
begin
  GC := World.GravityCoordinate;
  if MiddleForceBox then
    B := MiddleForceBoxValue else
    B := LocalBoundingBox;
  Result := MiddleHeight * (B.Data[1].Data[GC] - Bottom(Gravity, GC, B));

  {$ifdef CHECK_HEIGHT_VS_RADIUS}
  if Sphere(R) and (R > Result) then
  begin
    WritelnWarning('3D Radius',
      Format('PreferredHeight %f is smaller than radius %f. Gravity may work weird for this 3D object.',
      [Result, R]));
  end;
  {$endif}
end;

procedure TCastleTransform.UpdateSimpleGravity(const SecondsPassed: Single);

  procedure DoGravity(const PreferredHeight: Single);
  var
    GravityUp: TVector3;

    { TODO: this is a duplicate of similar TWalkCamera method }
    procedure DoFall;
    var
      BeginPos, EndPos, FallVector: TVector3;
    begin
      { Project Middle and FFallingStartMiddle
        onto GravityUp vector to calculate fall height. }
      BeginPos := PointOnLineClosestToPoint(TVector3.Zero, GravityUp, FFallingStartMiddle);
      EndPos   := PointOnLineClosestToPoint(TVector3.Zero, GravityUp, Middle);
      FallVector := BeginPos - EndPos;

      { Because of various growing and jumping effects (imagine you jump up
        onto a taller pillar) it may turn out that we're higher at the end
        at the end of fall. Do not report it to Fall event in this case. }
      if TVector3.DotProduct(GravityUp, FallVector.Normalize) <= 0 then
        Exit;

      Fall(FallVector.Length);
    end;

  const
    { HeightMargin is used to safeguard against floating point inaccuracy.
      Without this, creature would too often be considered "falling down"
      or "growing up". }
    HeightMargin = 1.01;
  var
    IsAbove: boolean;
    AboveHeight, RadiusIgnored: Single;
    OldFalling: boolean;
    FallingDistance, MaximumFallingDistance: Single;
  begin
    { calculate and save GravityUp once, it's used quite often in this procedure }
    GravityUp := World.GravityUp;

    OldFalling := FFalling;

    IsAbove := Height(Middle, AboveHeight);

    if (FallSpeed <> 0) and
       (AboveHeight > PreferredHeight * HeightMargin) then
    begin
      { Fall down }
      if not FFalling then
        FFallingStartMiddle := Middle;

      FFalling := true;

      FallingDistance := FallSpeed * SecondsPassed;
      if IsAbove then
      begin
        MaximumFallingDistance := AboveHeight - PreferredHeight;

        { If you will fall down by exactly
          AboveHeight - PreferredHeight,
          then you will get exatly into collision with the ground.
          So actually this is too large MaximumFallingDistance.

          But actually it's OK when Sphere is used, because then wall-sliding
          in MoveCollision can correct new position,
          so actually it will be slightly above the ground. So falling
          down will work.

          But when Sphere is not used, the situation is worse,
          because then MoveCollision doesn't do wall-sliding.
          And it will always simply reject such move
          with MaximumFallingDistance.
          If FPS is low (so we would like to fall down at once
          by large distance), this is noticeable: in such case, instead
          of falling down, creature hangs over the ground,
          because MoveCollision simply doesn't allow it fall
          exactly by AboveHeight - PreferredHeight.
          So MaximumFallingDistance has to be a little smaller in this case.
          In particular, this was noticeable for the initially dead alien
          creature on "Doom" level, when shadows were on (when shadows were on,
          FPS is low, that's why the bug was noticeable only with shadows = on).

          TODO: the better version would be to improve
          MoveCollision for Sphere=false case, instead of
          workarounding it here with this epsilon.
          See TBaseTrianglesOctree.MoveCollision. }
        if not Sphere(RadiusIgnored) then
          MaximumFallingDistance := MaximumFallingDistance - 0.01;
        MinVar(FallingDistance, MaximumFallingDistance);
      end;

      if not Move(GravityUp * -FallingDistance, true) then
        FFalling := false;
    end else
    begin
      FFalling := false;

      if (GrowSpeed <> 0) and
         (AboveHeight < PreferredHeight / HeightMargin) then
      begin
        { Growing up }
        Move(GravityUp * Min(GrowSpeed * SecondsPassed,
          PreferredHeight - AboveHeight), false);
      end;
    end;

    if OldFalling and (not FFalling) then
      DoFall;
  end;

var
  PH: Single;
begin
  if Gravity then
  begin
    PH := PreferredHeight;
    if (PH <> 0) and
       ((FallSpeed <> 0) or (GrowSpeed <> 0)) then
      { calculate and save PreferredHeight once,
        as it's used quite often in the DoGravity procedure }
      DoGravity(PH);
  end;
end;

procedure TCastleTransform.Fall(const FallHeight: Single);
begin
  { Nothing to do in this class }
end;

function TCastleTransform.Move(const ATranslation: TVector3;
  const BecauseOfGravity, EnableWallSliding: boolean): boolean;
var
  OldMiddle, ProposedNewMiddle, NewMiddle: TVector3;
begin
  OldMiddle := Middle;

  if EnableWallSliding then
  begin
    ProposedNewMiddle := OldMiddle + ATranslation;
    Result := MoveAllowed(OldMiddle, ProposedNewMiddle, NewMiddle, BecauseOfGravity);
  end else
  begin
    NewMiddle := OldMiddle + ATranslation;
    Result := MoveAllowed(OldMiddle, NewMiddle, BecauseOfGravity);
  end;

  if Result then
    Translate(NewMiddle - OldMiddle);
end;

procedure TCastleTransform.ChangedTransform;
begin
  VisibleChangeHere([vcVisibleGeometry]);
end;

{ We try hard to keep FOnlyTranslation return fast, and return with true.
  This allows TCastleTransform to be optimized and accurate
  for the (often) case of pure translation. }

function TCastleTransform.OnlyTranslation: boolean;
begin
  Result := FOnlyTranslation;
end;

procedure TCastleTransform.SetCenter(const Value: TVector3);
begin
  FCenter := Value;
  FOnlyTranslation := FOnlyTranslation and Value.IsPerfectlyZero;
  ChangedTransform;
end;

procedure TCastleTransform.SetRotation(const Value: TVector4);
begin
  FRotation := Value;
  FOnlyTranslation := FOnlyTranslation and (Value[3] = 0);
  ChangedTransform;
end;

procedure TCastleTransform.SetScale(const Value: TVector3);
begin
  FScale := Value;
  FOnlyTranslation := FOnlyTranslation and
    (Value[0] = 1) and (Value[1] = 1) and (Value[2] = 1);
  ChangedTransform;
end;

procedure TCastleTransform.SetScaleOrientation(const Value: TVector4);
begin
  FScaleOrientation := Value;
  FOnlyTranslation := FOnlyTranslation and (Value[3] = 0);
  ChangedTransform;
end;

function TCastleTransform.GetTranslation: TVector3;
begin
  Result := FTranslation;
end;

procedure TCastleTransform.SetTranslation(const Value: TVector3);
begin
  FTranslation := Value;
  ChangedTransform;
end;

procedure TCastleTransform.Translate(const T: TVector3);
begin
  Translation := Translation + T;
end;

procedure TCastleTransform.Identity;
begin
  Center := TVector3.Zero;
  Rotation := TVector4.Zero;
  Scale := NoScale;
  ScaleOrientation := TVector4.Zero;
  Translation := TVector3.Zero;
end;

function TCastleTransform.RotationFromDirectionUp(const D, U: TVector3): TVector4;
begin
  Result := OrientationFromDirectionUp(D, U,
    DefaultDirection[Orientation],
    DefaultUp[Orientation]
  );
end;

function TCastleTransform.RotationToDirection(const ARotation: TVector4): TVector3;
begin
  Result := RotatePointAroundAxis(ARotation, DefaultDirection[Orientation]);
end;

function TCastleTransform.RotationToUp(const ARotation: TVector4): TVector3;
begin
  Result := RotatePointAroundAxis(ARotation, DefaultUp[Orientation]);
end;

function TCastleTransform.GetDirection: TVector3;
begin
  Result := RotationToDirection(Rotation);
end;

function TCastleTransform.GetUp: TVector3;
begin
  Result := RotationToUp(Rotation);
end;

procedure TCastleTransform.SetDirection(const Value: TVector3);
var
  D, U: TVector3;
begin
  D := Value; // no need to normalize here
  U := GetUp;
  MakeVectorsOrthoOnTheirPlane(U, D);
  Rotation := RotationFromDirectionUp(D, U);
end;

procedure TCastleTransform.SetUp(const Value: TVector3);
var
  D, U: TVector3;
begin
  U := Value; // no need to normalize here
  D := GetDirection;
  MakeVectorsOrthoOnTheirPlane(D, U);
  Rotation := RotationFromDirectionUp(D, U);
end;

procedure TCastleTransform.UpPrefer(const AUp: TVector3);
var
  D, U: TVector3;
begin
  U := AUp; // no need to normalize here
  D := GetDirection;
  MakeVectorsOrthoOnTheirPlane(U, D);
  Rotation := RotationFromDirectionUp(D, U);
end;

procedure TCastleTransform.GetView(out APos, ADir, AUp: TVector3);
begin
  APos := Translation;
  ADir := Direction;
  AUp  := Up;
end;

procedure TCastleTransform.SetView(const APos, ADir, AUp: TVector3;
  const AdjustUp: boolean);
begin
  Translation := APos;
  SetView(ADir, AUp, AdjustUp);
end;

procedure TCastleTransform.SetView(const ADir, AUp: TVector3;
  const AdjustUp: boolean);
var
  D, U: TVector3;
begin
  D := ADir; // no need to normalize here
  U := AUp; // no need to normalize here
  if AdjustUp then
    MakeVectorsOrthoOnTheirPlane(U, D)
  else
    MakeVectorsOrthoOnTheirPlane(D, U);
  Rotation := RotationFromDirectionUp(D, U);
end;

{ TSceneManagerWorld ------------------------------------------------------------------- }

constructor TSceneManagerWorld.Create(AOwner: TComponent);
begin
  inherited;
  { everything inside is part of this world }
  AddToWorld(Self);
end;

function TSceneManagerWorld.GravityCoordinate: Integer;
begin
  Result := MaxAbsVectorCoord(GravityUp);
end;

function TSceneManagerWorld.WorldBoxCollision(const Box: TBox3D): boolean;
begin
  Result := BoxCollision(Box, nil);
end;

function TSceneManagerWorld.WorldSphereCollision(const Pos: TVector3;
  const Radius: Single): boolean;
begin
  Result := SphereCollision(Pos, Radius, nil);
end;

function TSceneManagerWorld.WorldSphereCollision2D(const Pos: TVector2;
  const Radius: Single;
  const Details: TCollisionDetails): boolean;
begin
  Result := SphereCollision2D(Pos, Radius, nil, Details);
end;

function TSceneManagerWorld.WorldPointCollision2D(const Point: TVector2): boolean;
begin
  Result := PointCollision2D(Point, nil);
end;

procedure TSceneManagerWorld.CameraChanged(ACamera: TCamera);
begin
  inherited;
  ACamera.GetView(FCameraWorldPosition, FCameraWorldDirection, FCameraWorldUp);
  FCameraViewKnown := true;
end;

end.

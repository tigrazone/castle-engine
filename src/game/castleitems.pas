{
  Copyright 2006-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Items, things that can be picked up, carried and used. }
unit CastleItems;

{$I castleconf.inc}

interface

uses Generics.Collections,
  CastleBoxes, X3DNodes, CastleScene, CastleVectors, CastleUtils,
  CastleClassUtils, Classes, CastleImages, CastleGLUtils,
  CastleResources, CastleGLImages,
  CastleXMLConfig, CastleSoundEngine, CastleFrustum,
  Castle3D, CastleTransform, CastleColors, CastleDebugTransform;

type
  TInventoryItem = class;
  TInventoryItemClass = class of TInventoryItem;

  { Basic resource of an item that can be picked up, used and such.

    A "resource" is an information shared by all items of given type,
    for example you can have two instances of class TItemResource:
    Sword and LifePotion. (Actually, TItemWeaponResource, which is a descendant
    of TItemResource, sounds like a better candidate for the Sword.)
    Using them, you can create milions of actual swords and life potions,
    and place them of your level (as well as in inventories of creatures
    able to carry items). Every life potion (TInventoryItem instance)
    may keep some individual information (for example, how much of the potion
    is already used/drunk), but all life potions will share the same
    TItemResource instance, so e.g. they all will be displayed using the same model
    on 3D level (TItemResource.BaseAnimation) and the same image in 2D inventory
    (TItemResource.Image). }
  TItemResource = class(T3DResource)
  strict private
    FBaseAnimation: T3DResourceAnimation;
    FCaption: string;
    FImageURL: string;
    FImage: TEncodedImage;
    FGLImage: TGLImage;
  private
    { The largest possible bounding box of the 3D item,
      taking into account that actual item 3D model will be rotated when
      placed on world. You usually want to add current item position to this. }
    function BoundingBoxRotated(const GravityUp: TVector3): TBox3D;
  protected
    procedure PrepareCore(const Params: TPrepareParams;
      const DoProgress: boolean); override;
    { Which TInventoryItem descendant to create when constructing item
      of this resource by CreateItem. }
    function ItemClass: TInventoryItemClass; virtual;
  public
    constructor Create(const AName: string); override;
    destructor Destroy; override;
    procedure LoadFromFile(ResourceConfig: TCastleConfig); override;

    { Nice caption to display. }
    property Caption: string read FCaption;

    property BaseAnimation: T3DResourceAnimation read FBaseAnimation;

    { 2D image representing an item, to be used when showing inventory and such.
      The core engine itself doesn't use it, and doesn't force anything
      about such image (whether it should have some specific size,
      whether it should have alpha channel and such).
      It is up to the final game to make use of these images.

      If you're wondering how to generate such image:
      one option is to open the item 3D model in
      [http://castle-engine.sourceforge.net/view3dscene.php]
      and use "Display -> Screenshot ..." menu option (maybe the one
      that makes transparent background).
      It is usually a good idea to also remember the camera used for such
      screenshot with "Console -> Print Current Camera (Viewpoint)..."
      menu option. }
    function Image: TEncodedImage;

    property ImageURL: string read FImageURL;

    { Resource to draw @link(Image). }
    function GLImage: TGLImage;

    { Create item. This is how you should create new TInventoryItem instances.
      It is analogous to TCreatureResource.CreateCreature, but now for items.

      Note that the item itself doesn't exist on a 3D world --- you have to
      put it there if you want by TInventoryItem.PutOnWorld. That is because items
      can also exist only in player's backpack and such, and then they
      are independent from 3D world.

      @bold(Examples:)

      You usually define your own item resources by adding a subdirectory with
      resource.xml file to your game data. See
      [http://castle-engine.sourceforge.net/creating_data_resources.php]
      and engine tutorial for examples how to do this. Then you load the item
      resources with

      @longCode(#
      var
        Sword: TItemResource;
      ...
        Resources.LoadFromFiles;
        Sword := Resources.FindName('Sword') as TItemResource;
      #)

      where 'Sword' is just our example item resource, assuming that one of your
      resource.xml files has resource with name="Sword".

      Now if you want to add the sword to your 3D world by code:

      Because TInventoryItem instance is automatically
      owned (freed) by the 3D world or inventory that contains it, a simplest
      example how to add an item to your 3D world is this:

      @longCode(#
        Sword.CreateItem(1).PutOnWorld(SceneManager.World, Vector3(2, 3, 4));
      #)

      This adds 1 item of the MyItemResource to the 3D world,
      on position (2, 3, 4). In simple cases you can get SceneManager
      instance from TCastleWindow.SceneManager or TCastleControl.SceneManager.

      If you want to instead add sword to the inventory of Player,
      you can call

      @longCode(#
        SceneManager.Player.PickItem(Sword.CreateItem(1));
      #)

      This assumes that you use SceneManager.Player property. It's not really
      obligatory, but it's the simplest way to have player with an inventory.
      See engine tutorial for examples how to create player.
      Anyway, if you have any TInventory instance, you can use
      TInventory.Pick to add TInventoryItem this way. }
    function CreateItem(const AQuantity: Cardinal): TInventoryItem;

    { Instantiate placeholder by create new item with CreateItem
      and putting it on level with TInventoryItem.PutOnWorld. }
    procedure InstantiatePlaceholder(World: TSceneManagerWorld;
      const APosition, ADirection: TVector3;
      const NumberPresent: boolean; const Number: Int64); override;

    function AlwaysPrepared: boolean; override;
  end;

  { Weapon that can make an immiediate attack (short-range/shoot)
    or fire a missile. }
  TItemWeaponResource = class(TItemResource)
  private
    FEquippingSound: TSoundType;
    FAttackAnimation: T3DResourceAnimation;
    FReadyAnimation: T3DResourceAnimation;
    FAttackTime: Single;
    FAttackSoundStart: TSoundType;
    FAttackAmmo: string;
    FAttackSoundHit: TSoundType;
    FAttackDamageConst: Single;
    FAttackDamageRandom: Single;
    FAttackKnockbackDistance: Single;
    FAttackShoot: boolean;
    FFireMissileName: string;
    FFireMissileSound: TSoundType;
  protected
    function ItemClass: TInventoryItemClass; override;
  public
    const
      DefaultAttackTime = 0.0;
      DefaultAttackDamageConst = 0.0;
      DefaultAttackDamageRandom = 0.0;
      DefaultAttackKnockbackDistance = 0.0;
      DefaultAttackShoot = false;

    constructor Create(const AName: string); override;

    { Sound to make on equipping. Each weapon can have it's own
      equipping sound. }
    property EquippingSound: TSoundType
      read FEquippingSound write FEquippingSound;

    { Animation of attack with this weapon. }
    property AttackAnimation: T3DResourceAnimation read FAttackAnimation;

    { Animation of keeping weapon ready. }
    property ReadyAnimation: T3DResourceAnimation read FReadyAnimation;

    { Common properties for all types of attack (short-range/shoot,
      fire missile) below. }

    { A time within AttackAnimationat at which TItemWeapon.Attack
      method will be called, which actually hits the enemy. }
    property AttackTime: Single read FAttackTime write FAttackTime
      default DefaultAttackTime;

    { Sound when attack starts. This is played when attack animation starts,
      and it means that we already checked that you have necessary ammunition
      (see AttackAmmo).
      None (stNone) by default. }
    property AttackSoundStart: TSoundType
      read FAttackSoundStart write FAttackSoundStart;

    { Ammunition required to make an attack (applies to both immediate attack,
      like short-range/shoot, and firing missiles).
      Indicates item resource name to use as ammunition (like 'Quiver' or 'Bullets').
      It may be empty, in which case the ammunition is not necessary to make
      an attack.
      If it's set, we will check whether owner of the weapon (like a player)
      has at least one item of this resource, and we'll decrease it
      when firing.

      For example, if this weapon is a pistol, then you can set
      AttackDamageConst and AttackDamageRandom to non-zero and AttackShoot
      to @true to perform an immediatele shooting attack.
      And set AttackAmmo to something like 'Bullets'.

      For example, if this weapon is a bow, then you can set
      FireMissileName to 'Arrow', to fire arrows as missiles (they will
      fly and can be avoided by fast moving enemies).
      And set AttackAmmo to something like 'Quiver'. }
    property AttackAmmo: string read FAttackAmmo write FAttackAmmo;

    { Immediate attack (short-range/shoot) damage and knockback.
      This type of attack (along with AttackSoundHit) is only
      done if one of these properties is non-zero. They must be >= 0.
      @groupBegin }
    property AttackDamageConst: Single read FAttackDamageConst write FAttackDamageConst
      default DefaultAttackDamageConst;
    property AttackDamageRandom: Single read FAttackDamageRandom write FAttackDamageRandom
      default DefaultAttackDamageRandom;
    property AttackKnockbackDistance: Single
      read FAttackKnockbackDistance write FAttackKnockbackDistance
      default DefaultAttackKnockbackDistance;
    { @groupEnd }

    { Does the immediate attack is shooting.

      @unorderedList(
        @item(Shooting means that the hit enemy is determined by casting a ray from
          owner (like a shooting player) and seeing what it hits. Even enemies
          far away may be hit, but you have to aim precisely.)

        @item(When this is @false, we make a short-range (melee) attack.
          In this case the hit enemy is determined by looking at the weapon
          bounding volume near owner. Only the enemies
          very close to the owner get hit.)
      ) }
    property AttackShoot: boolean read FAttackShoot write FAttackShoot
      default DefaultAttackShoot;

    { Sound on successful hit by an immediate attack (short-range/shoot). }
    property AttackSoundHit: TSoundType read FAttackSoundHit write FAttackSoundHit;

    { Creature resource name to be created (like 'Arrow') when firing a missile.
      Must be set to something not empty to actually fire a missile. }
    property FireMissileName: string read FFireMissileName write FFireMissileName;

    { Sound on missile fired.
      None (stNone) by default. }
    property FireMissileSound: TSoundType read FFireMissileSound write FFireMissileSound;

    procedure LoadFromFile(ResourceConfig: TCastleConfig); override;
  end;

  TItemOnWorld = class;
  TAliveWithInventory = class;

  { An item that can be used, kept in the inventory, or (using PutOnWorld
    that wraps it in TItemOnWorld) dropped on 3D world.
    Thanks to the @link(Quantity) property, this may actually represent
    many "stacked" items, all having the same properties. }
  TInventoryItem = class(TComponent)
  private
    FResource: TItemResource;
    FQuantity: Cardinal;
    FOwner3D: TCastleTransform;
  protected
    { Try to sum (stack) the given Item with current TInventoryItem.
      The idea is that if player has 5 arrows, and picks an item representing
      another 5 arrows, then we sum then into one TInventoryItem instance
      representing 10 arrows.

      Various games, and various items,
      may require various approaches: for example, maybe you don't want
      some items to stack at all (e.g. you want to only allow stacking
      for items naturally appearing in vast quantities, like arrows and bolts
      and bullets (if you represent them as TInventoryItem at all)).
      Maybe you want to allow stacking only to centain number, e.g. arrows
      are summed into groups of maximum 20 items, anything above creates new stack?
      Overriding this procedure allows you to do all this.

      You can here increase the Quantity of current item,
      decrease the Quantity of parameter Item. In case the parameter Item
      no longer exists (it's Quantity reaches 0) you have to free it
      and set to @nil the Item parameter, in practice you usually want
      to call then @code(FreeAndNil(Item)).

      The default implementation of this in TInventoryItem class
      allows stacking always, as long as the Resource matches.
      This means that, by default, every TItemResource is existing at most once
      in TAliveWithInventory.Inventory. }
    procedure Stack(var Item: TInventoryItem); virtual;

    { Item is picked by an alive player/creature.
      The default implementation in this class adds the item to the Inventory
      by calling TAliveWithInventory.PickItem.

      You can override this to cause different behavior (for example,
      to consume some items right at pickup).
      Remember that this method must take care of memory management
      of this item. }
    procedure Picked(const NewOwner: TAliveWithInventory); virtual;

    { Use this item.

      In this class, this just prints a message "this item cannot be used".

      Implementation of this method can assume for now that this is one of
      player's owned Items. Implementation of this method can change
      our properties, including Quantity.
      As a very special exception, implementation of this method
      is allowed to set Quantity of Item to 0.

      Never call this method when Player.Dead. Implementation of this
      method may assume that Player is not Dead.

      Caller of this method should always be prepared to immediately
      handle the "Quantity = 0" situation by freeing given item,
      removing it from any list etc. }
    procedure Use; virtual;
  public
    property Resource: TItemResource read FResource;

    { Quantity of this item.
      This must always be >= 1. }
    property Quantity: Cardinal read FQuantity write FQuantity;

    { Splits item (with Quantity >= 2) into two items.
      It returns newly created object with the same properties
      as this object, and with Quantity set to QuantitySplit.
      And it lowers our Quantity by QuantitySplit.

      Always QuantitySplit must be >= 1 and < Quantity. }
    function Split(QuantitySplit: Cardinal): TInventoryItem;

    { Create TItemOnWorld instance referencing this item,
      and add this to the given 3D AWorld.
      Although normal item knows (through Owner3D) the world it lives in,
      but this method may be used for items that don't have an owner yet,
      so we take AWorld parameter explicitly.
      This is how you should create new TItemOnWorld instances.
      It is analogous to TCreatureResource.CreateCreature, but now for items. }
    function PutOnWorld(const AWorld: TSceneManagerWorld;
      const APosition: TVector3): TItemOnWorld;

    { 3D owner of the item,
      like a player or creature (if the item is in the backpack)
      or the TItemOnWorld instance (if the item is lying on the world,
      pickable). May be @nil only in special situations (when item is moved
      from one 3D to another, and technically it's safer to @nil this
      property).

      The owner is always responsible for freeing this TInventoryItem instance
      (in case of TItemOnWorld, it does it directly;
      in case of player or creature, it does it by TInventory). }
    property Owner3D: TCastleTransform read FOwner3D;

    { 3D world of this item, if any.

      Although the TInventoryItem, by itself, is not a 3D thing
      (only pickable TItemOnWorld is a 3D thing).
      But it exists inside a 3D world: either as pickable (TItemOnWorld),
      or as being owned by a 3D object (like player or creature) that are
      part of 3D world. In other words, our Owner3D.World is the 3D world
      this item lives in. }
    function World: TSceneManagerWorld;
  end;

  TItemWeapon = class(TInventoryItem)
  private
    { Weapon AttackAnimation is in progress.}
    Attacking: boolean;
    { If Attacking, then this is time of attack start, from LifeTime. }
    AttackStartTime: Single;
    { If Attacking, then this says whether Attack was already called. }
    AttackDone: boolean;
  protected
    { Make real attack, immediate (short-range/shoot) or firing missile.
      Called during weapon TItemWeaponResource.AttackAnimation,
      at the time TItemWeaponResource.AttackTime.
      The default implementation in @className does a short-range/shoot
      attack (if AttackDamageConst or AttackDamageRandom or AttackKnockbackDistance
      non-zero) and fires a missile (if FireMissileName not empty). }
    procedure Attack; virtual;
    procedure Use; override;
  public
    function Resource: TItemWeaponResource;

    { Owner equips this weapon. }
    procedure Equip; virtual;

    { Owner starts attack with this equipped weapon. }
    procedure EquippedAttack(const LifeTime: Single); virtual;

    { Time passses for equipped weapon. }
    procedure EquippedUpdate(const LifeTime: Single); virtual;

    { Return the 3D model to render for this equipped weapon, or @nil if none. }
    function EquippedScene(const LifeTime: Single): TCastleScene; virtual;
  end;

  { List of items, with a 3D object (like a player or creature) owning
    these items. Do not directly change this list, always use
    the owner (TAliveWithInventory) methods like
    @link(TAliveWithInventory.PickItem) or
    @link(TAliveWithInventory.DropItem).
    They make sure that items are correctly stacked, and that
    TInventoryItem.Owner3D and memory management is good. }
  TInventory = class({$ifdef CASTLE_OBJFPC}specialize{$endif} TObjectList<TInventoryItem>)
  private
    FOwner3D: TAliveWithInventory;
  protected
    { Add Item to inventory. See TAliveWithInventory.PickItemUpdate description,
      this method actually implements it. }
    function Pick(var Item: TInventoryItem): Integer;

    { Drop item with given index.
      ItemIndex must be valid (between 0 and Items.Count - 1).
      You @italic(must) take care yourself of returned TInventoryItem memory
      management.
      This is the low-level basis for TAliveWithInventory.DropItem. }
    function Drop(const ItemIndex: Integer): TInventoryItem;

    { Pass here items owned by this list, immediately after decreasing
      their Quantity. This frees the item (removing it from the list)
      if it's quantity reached zero. }
    procedure CheckDepleted(const Item: TInventoryItem);

    { Use the item of given index.
      This is the low-level basis for TAliveWithInventory.UseItem. }
    procedure Use(const Index: Integer);
  public
    constructor Create(const AOwner3D: TAliveWithInventory);

    { Owner of the inventory (like a player or creature).
      Never @nil, always valid for given inventory.
      All items on this list always have the same TInventoryItem.Owner3D value
      as the inventory they are in. }
    property Owner3D: TAliveWithInventory read FOwner3D;

    { Searches for item of given Resource. Returns index of first found,
      or -1 if not found. }
    function FindResource(Resource: TItemResource): Integer;
  end;

  { Item that is placed on a 3D world, ready to be picked up.
    It's not in anyone's inventory. }
  TItemOnWorld = class(TCastleTransform)
  private
    type
      { A debug visualization that can be added to TItemOnWorld
        to visualize the parameters of it's parent (bounding volumes and such).
        See @link(TDebugTransform) for usage details. }
      TItemDebugTransform = class(TDebugTransform)
      strict private
        FBoxRotated: TDebugBox;
        FParent: TItemOnWorld;
      strict protected
        procedure Initialize; override;
        procedure Update; override;
      public
        procedure Attach(const AParent: TItemOnWorld);
      end;

    var
      FItem: TInventoryItem;
      FResourceFrame: TResourceFrame;
      ItemRotation, LifeTime: Single;
      FDebugTransform: TItemDebugTransform;
    function BoundingBoxRotated: TBox3D;
  public
    class var
      { Render debug bounding boxes and captions at every creature. }
      RenderDebug: boolean;

      { Speed of the rotation of 3D item on world.
        In radians per second, default is DefaultRotationSpeed.
        Set to zero to disable rotation. }
      RotationSpeed: Single;

      { Does the player automatically picks up items by walking over them.
        Default is @true. If you set this to @false, you most probably want to
        implement some other way of picking up items, use the ExtractItem method.

        More precisely, this variable controls when TInventoryItem.Picked
        is called. When @true, it is called for player when player steps over
        an item (otherwise it's never called).
        You can always override TInventoryItem.Picked for particular items
        to customize what happens at "pick" --- the default implementation
        picks an item by adding it to inventory, but you could override it
        e.g. to consume some potions immediately on pickup. }
      AutoPick: boolean;

    const
      DefaultRotationSpeed = Pi;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetExists: boolean; override;

    { The Item owned by this TItemOnWorld instance. Never @nil. }
    property Item: TInventoryItem read FItem;

    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;

    property Collides default false;
    property CollidesWithMoving default true;

    { Extract the @link(Item), used when picking up the TInventoryItem
      instance referenced by this TItemOnWorld instance. This returns our
      @link(Item) property, and clears it (clearing also TInventoryItem.Owner3D).
      At the next @link(Update), this TItemOnWorld instance will be freed
      and removed from 3D world.

      It's up to you what to do with resulting TInventoryItem instance.
      You can pick it up, by TAliveWithInventory.PickItem
      (for example player is an instance of TAliveWithInventory),
      or add it back to 3D world by TInventoryItem.PutOnWorld,
      or at least free it (or you'll get a memory leak). }
    function ExtractItem: TInventoryItem;
  end;

  { Alive 3D thing that has inventory (can keep items). }
  TAliveWithInventory = class(TAlive)
  private
    FInventory: TInventory;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Owned items. Never change the contents of this list directly,
      always use TAliveWithInventory methods like PickItem
      or DropItem for this. }
    property Inventory: TInventory read FInventory;

    { Add given Item to @link(Inventory).
      Because an item may be stacked with others,
      the actual Item instance may be freed and replaced with other by
      this method, that is why Item parameter is "var".
      Use PickItem method if you don't care about your Item instance.

      Returns index to the added item.

      Using this method means that the memory management of the item
      becomes the responsibility of this list. }
    function PickItemUpdate(var Item: TInventoryItem): Integer; virtual;

    { Add given Item to @link(Inventory). See PickItemUpdate for details.

      This is a shortcut to call PickItemUpdate and then ignore changes
      to Item instance. Calling this method may be comfortable,
      but remember that the Item instance possibly doesn't exist after we finish. }
    function PickItem(Item: TInventoryItem): Integer;

    { Drop item from @link(Inventory).
      It is Ok to pass here Index out of range, it will be ignored.
      @returns(Droppped item, or @nil if the operation was not completed due
        to any reason (e.g. no space on 3D world to fit this item).) }
    function DropItem(const Index: Integer): TItemOnWorld; virtual;

    { Use an item from @link(Inventory).
      Calls TInventoryItem.Use, and then checks whether
      the item was depleted (and eventually removes it from repository).
      It is Ok to pass here Index out of range, it will be ignored. }
    procedure UseItem(const Index: Integer); virtual;
  end;

  TItemOnWorldExistsEvent = function(const Item: TItemOnWorld): boolean of object;

var
  { Global callback to control items on level existence. }
  OnItemOnWorldExists: TItemOnWorldExistsEvent;

implementation

uses SysUtils, CastleFilesUtils, CastlePlayer, CastleGameNotifications,
  CastleConfig, CastleCreatures;

{ TItemResource ------------------------------------------------------------ }

constructor TItemResource.Create(const AName: string);
begin
  inherited;
  FBaseAnimation := T3DResourceAnimation.Create(Self, 'base');
end;

destructor TItemResource.Destroy;
begin
  FreeAndNil(FImage);
  FreeAndNil(FGLImage);
  inherited;
end;

procedure TItemResource.LoadFromFile(ResourceConfig: TCastleConfig);
begin
  inherited;

  FImageURL := ResourceConfig.GetURL('image');

  FCaption := ResourceConfig.GetValue('caption', '');
  if FCaption = '' then
    raise Exception.CreateFmt('Empty caption attribute for item "%s"', [Name]);
end;

function TItemResource.Image: TEncodedImage;
begin
  if FImage = nil then
    FImage := LoadEncodedImage(ImageURL);
  Result := FImage;
end;

function TItemResource.GLImage: TGLImage;
begin
  if FGLImage = nil then
    { TODO: this will load the ImageURL 2nd time. }
    FGLImage := TGLImage.Create(ImageURL);
  Result := FGLImage;
end;

procedure TItemResource.PrepareCore(const Params: TPrepareParams;
  const DoProgress: boolean);
begin
  inherited;
  { prepare GLImage now }
  GLImage;
end;

function TItemResource.CreateItem(const AQuantity: Cardinal): TInventoryItem;
begin
  Result := ItemClass.Create(nil { for now, TInventoryItem.Owner is always nil });
  { set properties that in practice must have other-than-default values
    to sensibly use the item }
  Result.FResource := Self;
  Result.FQuantity := AQuantity;
  Assert(Result.Quantity >= 1, 'Item''s Quantity must be >= 1');
end;

function TItemResource.ItemClass: TInventoryItemClass;
begin
  Result := TInventoryItem;
end;

procedure TItemResource.InstantiatePlaceholder(World: TSceneManagerWorld;
  const APosition, ADirection: TVector3;
  const NumberPresent: boolean; const Number: Int64);
var
  ItemQuantity: Cardinal;
begin
  { calculate ItemQuantity }
  if NumberPresent then
    ItemQuantity := Number else
    ItemQuantity := 1;

  CreateItem(ItemQuantity).PutOnWorld(World, APosition);
end;

function TItemResource.AlwaysPrepared: boolean;
begin
  Result := true;
end;

function TItemResource.BoundingBoxRotated(const GravityUp: TVector3): TBox3D;
var
  B: TBox3D;
begin
  B := FBaseAnimation.BoundingBox;
  Result :=
    B.Transform(RotationMatrixDeg(45         , GravityUp)) +
    B.Transform(RotationMatrixDeg(45 + 90    , GravityUp)) +
    B.Transform(RotationMatrixDeg(45 + 90 * 2, GravityUp)) +
    B.Transform(RotationMatrixDeg(45 + 90 * 3, GravityUp));
end;

{ TItemWeaponResource ------------------------------------------------------------ }

constructor TItemWeaponResource.Create(const AName: string);
begin
  inherited;
  FAttackAnimation := T3DResourceAnimation.Create(Self, 'attack');
  FReadyAnimation := T3DResourceAnimation.Create(Self, 'ready');
  FAttackTime := DefaultAttackTime;
  FAttackDamageConst := DefaultAttackDamageConst;
  FAttackDamageRandom := DefaultAttackDamageRandom;
  FAttackKnockbackDistance := DefaultAttackKnockbackDistance;
  FAttackShoot := DefaultAttackShoot;
end;

procedure TItemWeaponResource.LoadFromFile(ResourceConfig: TCastleConfig);
begin
  inherited;

  EquippingSound := SoundEngine.SoundFromName(
    ResourceConfig.GetValue('equipping_sound', ''));

  AttackTime := ResourceConfig.GetFloat('attack/time', DefaultAttackTime);
  AttackSoundStart := SoundEngine.SoundFromName(
    ResourceConfig.GetValue('attack/sound_start', ''));
  AttackAmmo := ResourceConfig.GetValue('attack/ammo', '');
  AttackSoundHit := SoundEngine.SoundFromName(
    ResourceConfig.GetValue('attack/sound_hit', ''));
  AttackDamageConst := ResourceConfig.GetFloat('attack/damage/const',
    DefaultAttackDamageConst);
  AttackDamageRandom := ResourceConfig.GetFloat('attack/damage/random',
    DefaultAttackDamageRandom);
  AttackKnockbackDistance := ResourceConfig.GetFloat('attack/knockback_distance',
    DefaultAttackKnockbackDistance);
  AttackShoot := ResourceConfig.GetValue('attack/shoot', DefaultAttackShoot);
  FireMissileName := ResourceConfig.GetValue('fire_missile/name', '');
  FireMissileSound := SoundEngine.SoundFromName(
    ResourceConfig.GetValue('fire_missile/sound', ''));
end;

function TItemWeaponResource.ItemClass: TInventoryItemClass;
begin
  Result := TItemWeapon;
end;

{ TInventoryItem ------------------------------------------------------------ }

procedure TInventoryItem.Stack(var Item: TInventoryItem);
begin
  if Item.Resource = Resource then
  begin
    { Stack Item with us }
    Quantity := Quantity + Item.Quantity;
    FreeAndNil(Item);
  end;
end;

function TInventoryItem.Split(QuantitySplit: Cardinal): TInventoryItem;
begin
  Check(Between(Integer(QuantitySplit), 1, Quantity - 1),
    'You must split >= 1 and less than current Quantity');

  Result := Resource.CreateItem(QuantitySplit);

  FQuantity := FQuantity - QuantitySplit;
end;

function TInventoryItem.PutOnWorld(const AWorld: TSceneManagerWorld;
  const APosition: TVector3): TItemOnWorld;
begin
  Result := TItemOnWorld.Create(AWorld { owner });
  { set properties that in practice must have other-than-default values
    to sensibly use the item }
  Result.FItem := Self;
  FOwner3D := Result;
  Result.SetView(APosition, AnyOrthogonalVector(AWorld.GravityUp), AWorld.GravityUp);
  Result.Gravity := true;
  Result.FallSpeed := Resource.FallSpeed;
  Result.GrowSpeed := Resource.GrowSpeed;
  Result.CastShadowVolumes := Resource.CastShadowVolumes;
  AWorld.Add(Result);
end;

procedure TInventoryItem.Use;
begin
  Notifications.Show('This item cannot be used');
end;

function TInventoryItem.World: TSceneManagerWorld;
begin
  if Owner3D <> nil then
    Result := Owner3D.World else
    Result := nil;
end;

procedure TInventoryItem.Picked(const NewOwner: TAliveWithInventory);
begin
  NewOwner.PickItem(Self);
end;

{ TItemWeapon ---------------------------------------------------------------- }

procedure TItemWeapon.Attack;
var
  Attacker: TAlive;
  AttackDC, AttackDR, AttackKD: Single;
  AttackSoundHitDone: boolean;

  procedure ImmediateAttackHit(Enemy: TAlive);
  begin
    if not AttackSoundHitDone then
    begin
      SoundEngine.Sound(Resource.AttackSoundHit);
      AttackSoundHitDone := true;
    end;
    Enemy.Hurt(AttackDC + Random * AttackDR, Attacker.Direction, AttackKD, Attacker);
  end;

  procedure ShootAttack;
  var
    I: Integer;
    Hit: TRayCollision;
  begin
    { TODO: allow some helpers for aiming,
      similar to TCastleSceneManager.ApproximateActivation
      or maybe just collide a tube (not infinitely thin ray) with world. }
    Hit := Attacker.Ray(Attacker.Middle, Attacker.Direction);
    if Hit <> nil then
    begin
      for I := 0 to Hit.Count - 1 do
        if Hit[I].Item is TAlive then
        begin
          ImmediateAttackHit(TAlive(Hit[I].Item));
          Break;
        end;
      FreeAndNil(Hit);
    end;
  end;

  procedure ShortRangeAttack;
  var
    I: Integer;
    Enemy: TAlive;
    WeaponBoundingBox: TBox3D;
  begin
    { Attacker.Direction may be multiplied by something here for long-range weapons }
    WeaponBoundingBox := Attacker.BoundingBox.Translate(Attacker.Direction);
    { Tests: Writeln('WeaponBoundingBox is ', WeaponBoundingBox.ToNiceStr); }
    { TODO: we would prefer to use World.BoxCollision for this,
      but we need to know which creature was hit. }
    for I := 0 to World.Count - 1 do
      if World[I] is TAlive then
      begin
        Enemy := TAlive(World[I]);
        { Tests: Writeln('Creature bbox is ', C.BoundingBox.ToNiceStr); }
        if (Enemy <> Attacker) and
          Enemy.BoundingBox.Collision(WeaponBoundingBox) then
          ImmediateAttackHit(Enemy);
      end;
  end;

  procedure FireMissileAttack;
  begin
    (Resources.FindName(Resource.FireMissileName) as TCreatureResource).
       CreateCreature(World, Attacker.Translation, Attacker.Direction);
    SoundEngine.Sound(Resource.FireMissileSound);
  end;

begin
  AttackSoundHitDone := false;

  { attacking only works when there's an owner (player, in the future creature
    should also be able to use it) of the weapon }
  if (Owner3D <> nil) and
     (Owner3D is TAlive) then
  begin
    Attacker := TAlive(Owner3D);

    AttackDC := Resource.AttackDamageConst;
    AttackDR := Resource.AttackDamageRandom;
    AttackKD := Resource.AttackKnockbackDistance;

    if (AttackDC >= 0) or
       (AttackDR >= 0) or
       (AttackKD >= 0) then
    begin
      if Resource.AttackShoot then
        ShootAttack else
        ShortRangeAttack;
    end;

    if Resource.FireMissileName <> '' then
      FireMissileAttack;
  end;
end;

procedure TItemWeapon.Use;
begin
  if (Owner3D <> nil) and
     (Owner3D is TPlayer) then
    TPlayer(Owner3D).EquippedWeapon := Self;
end;

function TItemWeapon.Resource: TItemWeaponResource;
begin
  Result := (inherited Resource) as TItemWeaponResource;
end;

procedure TItemWeapon.Equip;
begin
  SoundEngine.Sound(Resource.EquippingSound);

  { Just in case we had Attacking=true from previous weapon usage, clear it }
  Attacking := false;
end;

procedure TItemWeapon.EquippedAttack(const LifeTime: Single);

  { Check do you have ammunition to perform attack, and decrease it if yes. }
  function CheckAmmo: boolean;
  var
    Inventory: TInventory;
    AmmoIndex: Integer;
    AmmoItem: TInventoryItem;
    AmmoResource: TItemResource;
  begin
    { When AttackAmmo is set, check whether the owner has ammunition.
      Currently, only Player may have Inventory with items. }
    if Resource.AttackAmmo <> '' then
    begin
      if (Owner3D <> nil) and
         (Owner3D is TAliveWithInventory) then
      begin
        Inventory := TAliveWithInventory(Owner3D).Inventory;
        AmmoResource := Resources.FindName(Resource.AttackAmmo) as TItemResource;
        AmmoIndex := Inventory.FindResource(AmmoResource);
        Result := AmmoIndex <> -1;
        if Result then
        begin
          { delete ammunition from inventory }
          AmmoItem := Inventory[AmmoIndex];
          AmmoItem.Quantity := AmmoItem.Quantity - 1;
          Inventory.CheckDepleted(AmmoItem);
        end else
        begin
          Notifications.Show('You have no ammunition');
          SoundEngine.Sound(stPlayerInteractFailed);
        end;
      end else
        Result := false; // other creatures cannot have ammo for now
    end else
      Result := true; // no ammo required
  end;

begin
  if (not Attacking) and CheckAmmo then
  begin
    SoundEngine.Sound(Resource.AttackSoundStart);
    AttackStartTime := LifeTime;
    Attacking := true;
    AttackDone := false;

    { if AttackTime = 0, attack immediately, otherwise this could get aborted
      by TItemWeapon.EquippedScene if AttackAnim.Duration = 0. }
    if Resource.AttackTime = 0 then
    begin
      AttackDone := true;
      Attack;
    end;
  end;
end;

procedure TItemWeapon.EquippedUpdate(const LifeTime: Single);
begin
  if Attacking and (not AttackDone) and
    (LifeTime - AttackStartTime >= Resource.AttackTime) then
  begin
    AttackDone := true;
    Attack;
  end;
end;

function TItemWeapon.EquippedScene(const LifeTime: Single): TCastleScene;
var
  AttackTime: Single;
  AttackAnim: T3DResourceAnimation;
begin
  if not Resource.Prepared then Exit(nil);

  AttackAnim := Resource.AttackAnimation;
  AttackTime := LifeTime - AttackStartTime;
  if Attacking and (AttackTime <= AttackAnim.Duration) then
  begin
    Result := AttackAnim.Scene(AttackTime, false);
  end else
  begin
    { turn off Attacking, if AttackTime passed }
    Attacking := false;
    { although current weapons animations are just static,
      we use LifeTime to enable any weapon animation
      (like weapon swaying, or some fire over the sword or such) in the future. }
    Result :=  Resource.ReadyAnimation.Scene(LifeTime, true);
  end;
end;

{ TInventory ------------------------------------------------------------ }

constructor TInventory.Create(const AOwner3D: TAliveWithInventory);
begin
  inherited Create(true);
  FOwner3D := AOwner3D;
end;

function TInventory.FindResource(Resource: TItemResource): Integer;
begin
  for Result := 0 to Count - 1 do
    if Items[Result].Resource = Resource then
      Exit;
  Result := -1;
end;

function TInventory.Pick(var Item: TInventoryItem): Integer;
begin
  for Result := 0 to Count - 1 do
  begin
    Items[Result].Stack(Item);
    if Item = nil then Break;
  end;

  if Item <> nil then
  begin
    Add(Item);
    Result := Count - 1;
  end else
    Item := Items[Result];

  Item.FOwner3D := Owner3D;
end;

function TInventory.Drop(const ItemIndex: Integer): TInventoryItem;
var
  SelectedItem: TInventoryItem;
  DropQuantity: Cardinal;
begin
  SelectedItem := Items[ItemIndex];

  { For now, always drop 1 item.
    This makes it independent from message boxes, and also suitable for
    items owned by creatures.

  if SelectedItem.Quantity > 1 then
  begin
    DropQuantity := SelectedItem.Quantity;

    if not MessageInputQueryCardinal(Window,
      Format('You have %d items "%s". How many of them do you want to drop ?',
        [SelectedItem.Quantity, SelectedItem.Resource.Caption]),
      DropQuantity) then
      Exit(nil);

    if not Between(DropQuantity, 1, SelectedItem.Quantity) then
    begin
      Notifications.Show(Format('You cannot drop %d items', [DropQuantity]));
      Exit(nil);
    end;
  end else }
    DropQuantity := 1;

  if DropQuantity = SelectedItem.Quantity then
  begin
    Result := SelectedItem;
    Extract(SelectedItem); { Extract, not Remove, do not free }
  end else
  begin
    Result := SelectedItem.Split(DropQuantity);
  end;

  Result.FOwner3D := nil;
end;

procedure TInventory.CheckDepleted(const Item: TInventoryItem);
var
  Index: Integer;
begin
  if Item.Quantity = 0 then
  begin
    Index := IndexOf(Item);
    if Index <> -1 then
      Delete(Index);
  end;
end;

procedure TInventory.Use(const Index: Integer);
var
  Item: TInventoryItem;
begin
  Item := Items[Index];
  Item.Use;
  { CheckDepleted will search for new index, since using an item
    may change the items list and so change the index. }
  CheckDepleted(Item);
end;

{ TItemOnWorld.TItemDebugTransform -------------------------------------------------------- }

procedure TItemOnWorld.TItemDebugTransform.Initialize;
begin
  inherited;

  FBoxRotated := TDebugBox.Create(Self, GrayRGB);
  WorldSpace.AddChildren(FBoxRotated.Root);

  ChangedScene;
end;

procedure TItemOnWorld.TItemDebugTransform.Attach(const AParent: TItemOnWorld);
begin
  FParent := AParent;
  inherited Attach(AParent);
end;

procedure TItemOnWorld.TItemDebugTransform.Update;
var
  BBoxRotated: TBox3D;
begin
  inherited;

  // show FParent.BoundingBoxRotated
  BBoxRotated := FParent.BoundingBoxRotated;
  FBoxRotated.Box := BBoxRotated;
end;

{ TItemOnWorld ------------------------------------------------------------ }

constructor TItemOnWorld.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  CollidesWithMoving := true;
  Gravity := true;

  FDebugTransform := TItemDebugTransform.Create(Self);
  FDebugTransform.Attach(Self);

  { Items are not collidable, player can enter them to pick them up.
    For now, this also means that creatures can pass through them,
    which isn't really troublesome now. }
  Collides := false;

  FResourceFrame := TResourceFrame.Create(Self);
  Add(FResourceFrame);
end;

destructor TItemOnWorld.Destroy;
begin
  FreeAndNil(FItem);
  inherited;
end;

function TItemOnWorld.BoundingBoxRotated: TBox3D;
begin
  Result := Item.Resource.BoundingBoxRotated(World.GravityUp).Translate(Translation);
end;

procedure TItemOnWorld.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);

  procedure UpdateResourceFrame;
  begin
    if Item = nil then Exit;
    FResourceFrame.SetFrame(Item.Resource.BaseAnimation, LifeTime, true);
  end;

var
  DirectionZero, U: TVector3;
begin
  inherited;
  if not GetExists then Exit;

  LifeTime := LifeTime + SecondsPassed;

  { LifeTime is used to choose animation frame in GetChild.
    So the item constantly changes, even when it's
    transformation (things taken into account in TCastleTransform) stay equal. }
  VisibleChangeHere([vcVisibleGeometry]);

  ItemRotation := ItemRotation + (RotationSpeed * SecondsPassed);
  U := World.GravityUp; // copy to local variable for speed
  DirectionZero := AnyOrthogonalVector(U).Normalize;
  SetView(RotatePointAroundAxisRad(ItemRotation, DirectionZero, U), U);

  FDebugTransform.Exists := RenderDebug;

  if AutoPick and
     (World.Player <> nil) and
     (World.Player is TAliveWithInventory) and
     (not (World.Player as TAlive).Dead) and
     BoundingBox.Collision(World.Player.BoundingBox) then
    ExtractItem.Picked(TAliveWithInventory(World.Player));

  { Since we cannot live with Item = nil, we free ourselves }
  if Item = nil then
    RemoveMe := rtRemoveAndFree;

  UpdateResourceFrame;
end;

function TItemOnWorld.ExtractItem: TInventoryItem;
begin
  { We no longer own this Item, so clear references. }
  Result := Item;
  Result.FOwner3D := nil;
  FItem := nil;
end;

function TItemOnWorld.GetExists: boolean;
begin
  Result := (inherited GetExists) and
    ((not Assigned(OnItemOnWorldExists)) or OnItemOnWorldExists(Self));
end;

{ TAliveWithInventory ------------------------------------------------------ }

constructor TAliveWithInventory.Create(AOwner: TComponent);
begin
  inherited;
  FInventory := TInventory.Create(Self);
end;

destructor TAliveWithInventory.Destroy;
begin
  FreeAndNil(FInventory);
  inherited;
end;

function TAliveWithInventory.PickItemUpdate(var Item: TInventoryItem): Integer;
begin
  Result := Inventory.Pick(Item);
end;

function TAliveWithInventory.PickItem(Item: TInventoryItem): Integer;
begin
  Result := PickItemUpdate(Item);
end;

function TAliveWithInventory.DropItem(const Index: Integer): TItemOnWorld;

  function DirectionInGravityPlane: TVector3;
  var
    GravityUp: TVector3;
  begin
    GravityUp := World.GravityUp;
    Result := Direction;
    if not VectorsParallel(Result, GravityUp) then
      MakeVectorsOrthoOnTheirPlane(Result, GravityUp);
  end;

  function GetItemDropTranslation(DroppedItemResource: TItemResource;
    out DropTranslation: TVector3): boolean;
  var
    ItemBox: TBox3D;
    ItemBoxRadius: Single;
    ItemBoxMiddle: TVector3;
  begin
    ItemBox := DroppedItemResource.BoundingBoxRotated(World.GravityUp);
    ItemBoxMiddle := ItemBox.Center;
    { Box3DRadius calculates radius around (0, 0, 0) and we want
      radius around ItemBoxMiddle }
    ItemBoxRadius := ItemBox.Translate(-ItemBoxMiddle).Radius;

    { Calculate DropTranslation.

      We must move the item a little before us to
      1. show visually player that the item was dropped
      2. to avoid automatically picking it again

      Note that I take direction from DirectionInGravityPlane,
      not from Direction, otherwise when player is looking
      down he could be able to put item "inside the ground".
      Collision detection with the level below would actually
      prevent putting item "inside the ground", but the item
      would be too close to the player --- he could pick it up
      immediately. }
    DropTranslation := Translation +
      DirectionInGravityPlane *
        (0.6 * (PreferredHeight * Sqrt3 + ItemBox.Diagonal));

    { Now check is DropTranslation actually possible
      (i.e. check collisions item<->everything).
      The assumption is that item starts from
      Translation and is moved to DropTranslation.

      But actually we must shift both these positions,
      so that we check positions that are ideally in the middle
      of item's BoundingBoxRotated. Otherwise the item
      could get *partially* stuck within the wall, which wouldn't
      look good. }

    Result := World.WorldMoveAllowed(
      ItemBoxMiddle + Translation,
      ItemBoxMiddle + DropTranslation, true, ItemBoxRadius,
      ItemBox.Translate(Translation),
      ItemBox.Translate(DropTranslation), false);
  end;

var
  DropTranslation: TVector3;
  DropppedItem: TInventoryItem;
begin
  Result := nil;

  if Between(Index, 0, Inventory.Count - 1) then
  begin
    if GetItemDropTranslation(Inventory[Index].Resource, DropTranslation) then
    begin
      DropppedItem := Inventory.Drop(Index);
      Result := DropppedItem.PutOnWorld(World, DropTranslation);
    end;
  end;
end;

procedure TAliveWithInventory.UseItem(const Index: Integer);
begin
  if Between(Index, 0, Inventory.Count - 1) then
    Inventory.Use(Index);
end;

initialization
  TItemOnWorld.RotationSpeed := TItemOnWorld.DefaultRotationSpeed;
  TItemOnWorld.AutoPick := true;

  RegisterResourceClass(TItemResource, 'Item');
  RegisterResourceClass(TItemWeaponResource, 'Weapon');
end.

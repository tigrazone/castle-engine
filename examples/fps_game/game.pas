{
  Copyright 2012-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Example of a fully-working 3D FPS game.
  This is the main game unit, which contains most of the code.
  This is a cross-platform game code that will work on any platform
  (desktop or mobile). }
unit Game;

interface

implementation

uses SysUtils, Classes,
  CastleWindow, CastleLog, CastleConfig, CastleLevels,
  CastlePlayer, CastleSoundEngine, CastleProgress, CastleWindowProgress,
  CastleResources, CastleControls, CastleKeysMouse, CastleStringUtils,
  CastleTransform, CastleFilesUtils, CastleGameNotifications, CastleWindowTouch,
  CastleSceneManager, CastleVectors, CastleUIControls, CastleGLUtils,
  CastleColors, CastleItems, CastleUtils, CastleCameras, CastleMaterialProperties,
  CastleCreatures, CastleRectangles, CastleImages, CastleApplicationProperties;

var
  Window: TCastleWindowTouch;
  SceneManager: TGameSceneManager; //< same thing as Window.SceneManager
  Player: TPlayer; //< same thing as Window.SceneManager.Player
  ExtraViewport: TCastleViewport;
  CreaturesSpawned: Integer;

{ Buttons -------------------------------------------------------------------- }

type
  { Container for buttons and their callbacks.
    You could as well derive descendant of TCastleWindow to keep your
    callbacks, or place these callbacks as methods of Lazarus form. }
  TButtons = class(TComponent)
    ToggleMouseLookButton: TCastleButton;
    ExitButton: TCastleButton;
    RenderDebugCreaturesButton: TCastleButton;
    RenderDebugItemsButton: TCastleButton;
    ScrenshotButton: TCastleButton;
    AddCreatureButton: TCastleButton;
    AddItemButton: TCastleButton;
    AttackButton: TCastleButton;
    constructor Create(AOwner: TComponent); override;
    procedure ToggleMouseLookButtonClick(Sender: TObject);
    procedure ExitButtonClick(Sender: TObject);
    procedure RenderDebugCreaturesButtonClick(Sender: TObject);
    procedure RenderDebugItemsButtonClick(Sender: TObject);
    procedure ScreenshotButtonClick(Sender: TObject);
    procedure AddCreatureButtonClick(Sender: TObject);
    procedure AddItemButtonClick(Sender: TObject);
    procedure AttackButtonClick(Sender: TObject);
  end;

const
  ControlsMargin = 8;

constructor TButtons.Create(AOwner: TComponent);
var
  NextButtonBottom: Integer;
begin
  inherited;

  NextButtonBottom := ControlsMargin;

  if not Application.TouchDevice then
  begin
    ToggleMouseLookButton := TCastleButton.Create(Application);
    ToggleMouseLookButton.Caption := 'Mouse Look (F4)';
    ToggleMouseLookButton.Toggle := true;
    ToggleMouseLookButton.OnClick := @ToggleMouseLookButtonClick;
    ToggleMouseLookButton.Left := ControlsMargin;
    ToggleMouseLookButton.Bottom := NextButtonBottom;
    Window.Controls.InsertFront(ToggleMouseLookButton);
    NextButtonBottom := NextButtonBottom + (ToggleMouseLookButton.CalculatedHeight + ControlsMargin);
  end;

  ExitButton := TCastleButton.Create(Application);
  ExitButton.Caption := 'Exit (Escape)';
  ExitButton.OnClick := @ExitButtonClick;
  ExitButton.Left := ControlsMargin;
  ExitButton.Bottom := NextButtonBottom;
  Window.Controls.InsertFront(ExitButton);
  NextButtonBottom := NextButtonBottom + (ExitButton.CalculatedHeight + ControlsMargin);

  RenderDebugCreaturesButton := TCastleButton.Create(Application);
  RenderDebugCreaturesButton.Caption := 'Creatures Debug Visualization';
  RenderDebugCreaturesButton.Toggle := true;
  RenderDebugCreaturesButton.OnClick := @RenderDebugCreaturesButtonClick;
  RenderDebugCreaturesButton.Left := ControlsMargin;
  RenderDebugCreaturesButton.Bottom := NextButtonBottom;
  Window.Controls.InsertFront(RenderDebugCreaturesButton);
  NextButtonBottom := NextButtonBottom + (RenderDebugCreaturesButton.CalculatedHeight + ControlsMargin);

  RenderDebugItemsButton := TCastleButton.Create(Application);
  RenderDebugItemsButton.Caption := 'Items Debug Visualization';
  RenderDebugItemsButton.Toggle := true;
  RenderDebugItemsButton.OnClick := @RenderDebugItemsButtonClick;
  RenderDebugItemsButton.Left := ControlsMargin;
  RenderDebugItemsButton.Bottom := NextButtonBottom;
  Window.Controls.InsertFront(RenderDebugItemsButton);
  NextButtonBottom := NextButtonBottom + (RenderDebugItemsButton.CalculatedHeight + ControlsMargin);

  ScrenshotButton := TCastleButton.Create(Application);
  ScrenshotButton.Caption := 'Screenshot (F5)';
  ScrenshotButton.OnClick := @ScreenshotButtonClick;
  ScrenshotButton.Left := ControlsMargin;
  ScrenshotButton.Bottom := NextButtonBottom;
  Window.Controls.InsertFront(ScrenshotButton);
  NextButtonBottom := NextButtonBottom + (ScrenshotButton.CalculatedHeight + ControlsMargin);

  AddCreatureButton := TCastleButton.Create(Application);
  AddCreatureButton.Caption := 'Add creature (F9)';
  AddCreatureButton.OnClick := @AddCreatureButtonClick;
  AddCreatureButton.Left := ControlsMargin;
  AddCreatureButton.Bottom := NextButtonBottom;
  Window.Controls.InsertFront(AddCreatureButton);
  NextButtonBottom := NextButtonBottom + (AddCreatureButton.CalculatedHeight + ControlsMargin);

  AddItemButton := TCastleButton.Create(Application);
  AddItemButton.Caption := 'Add item (F10)';
  AddItemButton.OnClick := @AddItemButtonClick;
  AddItemButton.Left := ControlsMargin;
  AddItemButton.Bottom := NextButtonBottom;
  Window.Controls.InsertFront(AddItemButton);
  NextButtonBottom := NextButtonBottom + (AddItemButton.CalculatedHeight + ControlsMargin);

  AttackButton := TCastleButton.Create(Application);
  AttackButton.Caption := 'Attack (Ctrl)';
  AttackButton.OnClick := @AttackButtonClick;
  AttackButton.Left := ControlsMargin;
  AttackButton.Bottom := NextButtonBottom;
  Window.Controls.InsertFront(AttackButton);
  NextButtonBottom := NextButtonBottom + (AttackButton.CalculatedHeight + ControlsMargin);
end;

procedure TButtons.ToggleMouseLookButtonClick(Sender: TObject);
begin
  ToggleMouseLookButton.Pressed := not ToggleMouseLookButton.Pressed;
  Player.Camera.MouseLook := ToggleMouseLookButton.Pressed;
end;

procedure TButtons.ExitButtonClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TButtons.RenderDebugCreaturesButtonClick(Sender: TObject);
begin
  RenderDebugCreaturesButton.Pressed := not RenderDebugCreaturesButton.Pressed;
  TCreature.RenderDebug := RenderDebugCreaturesButton.Pressed;
end;

procedure TButtons.RenderDebugItemsButtonClick(Sender: TObject);
begin
  RenderDebugItemsButton.Pressed := not RenderDebugItemsButton.Pressed;
  TItemOnWorld.RenderDebug := RenderDebugItemsButton.Pressed;
end;

procedure TButtons.ScreenshotButtonClick(Sender: TObject);
var
  URL: string;
begin
  { Capture a screenshot straight to a file.
    There are more interesting things that you can do with a screenshot
    (overloaded Window.SaveScreen returns you a TRGBImage and we have
    a whole image library in CastleImages unit to process such image).
    You could also ask use to choose a file (e.g. by Window.FileDialog).
    But this is just a simple example, and this way we also have
    an opportunity to show how to use Notifications. }
  URL := FileNameAutoInc(ApplicationName + '_screen_%d.png');
  Window.SaveScreen(URL);
  Notifications.Show('Saved screen to ' + URL);
end;

procedure TButtons.AddCreatureButtonClick(Sender: TObject);
var
  Translation: TVector3;
  Direction: TVector3;
  CreatureResource: TCreatureResource;
begin
  Translation := Player.Translation + Player.Direction * 10;
  { increase default height, as dropping from above looks better }
  Translation.Data[1] := Translation.Data[1] + 5;
  Direction := Player.Direction; { by default creature is facing back to player }
  CreatureResource := Resources.FindName('Knight') as TCreatureResource;
  { CreateCreature creates TCreature instance and adds it to SceneManager.Items }
  CreatureResource.CreateCreature(SceneManager.Items, Translation, Direction);

  // update and show CreaturesSpawned
  Inc(CreaturesSpawned);
  AddCreatureButton.Caption := Format('Add creature (F9) (Spawned: %d)',
    [CreaturesSpawned]);
end;

procedure TButtons.AddItemButtonClick(Sender: TObject);
var
  Translation: TVector3;
  ItemResource: TItemResource;
begin
  Translation := Player.Translation + Player.Direction * 10;
  { increase default height, as dropping from above looks better }
  Translation.Data[1] := Translation.Data[1] + 5;
  ItemResource := Resources.FindName('MedKit') as TItemResource;
  { ItemResource.CreateItem(<quantity>) creates new TInventoryItem instance.
    PutOnWorld method creates TItemOnWorld (that "wraps" the TInventoryItem
    instance) and adds it to SceneManager.Items. }
  ItemResource.CreateItem(1).PutOnWorld(SceneManager.Items, Translation);

  { You could instead add the item directly to someone's inventory, like this: }
  // Player.PickItem(ItemResource.CreateItem(1));
end;

procedure TButtons.AttackButtonClick(Sender: TObject);
begin
  Player.Attack;
end;

var
  Buttons: TButtons;

{ Player HUD ---------------------------------------------------------------- }

type
  TPlayerHUD = class(TUIControl)
  public
    procedure Render; override;
  end;

procedure TPlayerHUD.Render;
const
  InventoryImageSize = 128;
var
  Player: TPlayer;
  I, X, Y: Integer;
  S: string;
begin
  inherited;
  Player := SceneManager.Player;

  Y := ContainerHeight;

  { A simple display of current/maximum player life. }
  { Write text in the upper-left corner of the screen.
    The (0, 0) position is always bottom-left corner,
    (ContainerWidth, ContainerHeight) position is top-right corner.
    You can take font measurements by UIFont.RowHeight or UIFont.TextWidth
    to adjust initial position as needed. }
  Y := Y - (UIFont.RowHeight + ControlsMargin);
  UIFont.Print(ControlsMargin, Y, Yellow,
    Format('Player life: %f / %f', [Player.Life, Player.MaxLife]));

  { show FPS }
  UIFont.PrintRect(Window.Rect.Grow(-ControlsMargin), Red,
    Format('FPS: %f', [Window.Fps.RealTime]), hpRight, vpTop);

  Y := Y - (UIFont.RowHeight + InventoryImageSize);

  { Mark currently chosen item. You can change currently selected item by
    Input_InventoryPrevious, Input_InventoryNext (by default: [ ] keys or mouse
    wheel). }
  if Between(Player.InventoryCurrentItem, 0, Player.Inventory.Count - 1) then
  begin
    X := ControlsMargin + Player.InventoryCurrentItem * (InventoryImageSize + ControlsMargin);
    { This allows to draw a standard tiActiveFrame image.
      You could change the image by assigning Theme.Images[tiActiveFrame]
      (and choosing one of your own images or one of the predefined images
      in CastleControlsImages, see main program code for example),
      or by creating and using TGLImage.Draw3x3 or TGLImage.Draw directly. }
    Theme.Draw(Rectangle(X, Y, InventoryImageSize, InventoryImageSize), tiActiveFrame);
  end;

  { A simple way to draw player inventory.
    The image representing each item (exactly for purposes like inventory
    display) is specified in the resource.xml file of each item,
    as image="xxx" attribute of the root <resource> element.
    Based on this, the engine initializes TItemResource.Image and TItemResource.GLImage,
    that you can easily use for any purpose.
    We assume below that all item images have square size
    InventoryImageSize x InventoryImageSize,
    and we assume that all items will always fit within one row. }
  for I := 0 to Player.Inventory.Count - 1 do
  begin
    X := ControlsMargin + I * (InventoryImageSize + ControlsMargin);
    Player.Inventory[I].Resource.GLImage.Draw(X, Y);
    S := Player.Inventory[I].Resource.Caption;
    if Player.Inventory[I].Quantity <> 1 then
      S := S + Format(' (%d)', [Player.Inventory[I].Quantity]);
    UIFont.Print(X, Y - UIFont.RowHeight, Yellow, S);
  end;

  { Simple color effects over the screen:
    when player is dead,
    when player is underwater,
    when player has fadeout from any other cause (e.g. player is hurt).

    DrawRectangle and GLFaceRectangle make simple color effects by blending.
    They are trivial to use (by all means, do experiment with parameters below,
    see DrawRectangle and GLFaceRectangle documentation and also OpenGL
    glBlendFunc parameters), and they will work even on ancient GPUs.

    To create more fancy effects, you can use our GLSL screen effects API.
    See http://castle-engine.sourceforge.net/x3d_extensions_screen_effects.php .
    They can be even set up completely in VRML/X3D file (no need for ObjectPascal
    code). Engine example examples/3d_rendering_processing/multiple_viewports.lpr
    shows how to set them up in code. }
  if Player.Swimming = psUnderWater then
    DrawRectangle(ParentRect, Vector4(0, 0, 0.1, 0.5));
  if Player.Dead then
    GLFadeRectangleDark(ParentRect, Red, 1.0) else
    GLFadeRectangleDark(ParentRect, Player.FadeOutColor, Player.FadeOutIntensity);
end;

var
  PlayerHUD: TPlayerHUD;

{ Window callbacks ----------------------------------------------------------- }

procedure Press(Container: TUIContainer; const Event: TInputPressRelease);
begin
  { We simulate button presses on some key presses. There is no automatic
    mechanism to assign key shortcut to a TCastleButton right now.
    Note that we pass Sender = nil to the callbacks, because we know that
    our TButtons callbacks ignore Sender parameter. }
  if Event.IsKey(K_F4) then
    Buttons.ToggleMouseLookButtonClick(nil) else
  if Event.IsKey(CharEscape) then
    Buttons.ExitButtonClick(nil) else
  if Event.IsKey(K_F5) then
    Buttons.ScreenshotButtonClick(nil) else
  if Event.IsKey(K_F9) then
    Buttons.AddCreatureButtonClick(nil) else
  if Event.IsKey(K_F10) then
    Buttons.AddItemButtonClick(nil);
end;

{ Customized item ------------------------------------------------------------ }

type
  { An example how to create new item behavior.

    We override both the resource class (shared information for a given kind
    of item; instances of it will be automatically
    created and placed on the global Resources list, based on resource.xml files
    referring to this class by type="xxx") and non-resource class
    (information about a particular occurence of this item).
    See engine tutorial for more extensive explanation.
    Creating new creatures looks the same.

    In this simplest case, the only purpose of the TMedKitResource class is to
    indicate the non-resource class TMedKit.

    For actual item TMedKit we override the Use method
    to increase health on use (press Enter to use item in inventory).

    We also override the Stack property to avoid stacking items.
    We do this here just to see that TPlayerHUD works for many items.
    (Otherwise, all instances of MedKit would be "stacked" together,
    which means you will have a single item on Player.Inventory,
    but with Quantity possibly > 1. For real games, stacking is usually a good
    idea.) }
  TMedKitResource = class(TItemResource)
  protected
    function ItemClass: TInventoryItemClass; override;
  end;

  TMedKit = class(TInventoryItem)
  protected
    procedure Stack(var Item: TInventoryItem); override;
    procedure Use; override;
    // procedure Picked(const NewOwner: TAliveWithInventory); override;
  end;

function TMedKitResource.ItemClass: TInventoryItemClass;
begin
  Result := TMedKit;
end;

procedure TMedKit.Stack(var Item: TInventoryItem);
begin
  { Simply do nothing to prevent stacking medkit items. }
end;

procedure TMedKit.Use;
begin
  { Increase the life of item's owner.

    We could of course do something more intelligent here, e.g. do not allow
    increasing Life above MaxLife (by default, there is *no* such limit,
    you can increase Life above MaxLife, because many games allow
    increasing Life by some magical powerups above normal "maximum" value).

    You could also allow partially using an item, by keeping a property
    like Used inside TMedKit class. You would decrease this TMedKit.Used
    property instead of Quantity (and only decrease Quantity when TMedKit.Used
    reaches 0, which means that item was used up completely). }
  Player.Life := Player.Life + 20;
  Quantity := Quantity - 1;
  Notifications.Show(Format('You use "%s"', [Resource.Caption]));
  { A simplest demo how to play sound defined in sounds/index.xml }
  SoundEngine.Sound(SoundEngine.SoundFromName('medkit_use'));
end;

{ If you want to do something immediately at pickup, you can override
  Picked method. By default, it causes item to be added to inventory,
  but you could as well e.g. immediately increase player life and destroy item.
  Uncomment this method (and it's declaration in TMedKit class) to test it. }
// procedure TMedKit.Picked(const NewOwner: TAliveWithInventory);
// begin
//   Use;
//   Free;
// end;

{ initialization ------------------------------------------------------------- }

{ Initialize the game.
  This is assigned to Application.OnInitialize, and will be called only once. }
procedure ApplicationInitialize;
begin
  { automatically scale user interface to reference sizes }
  Window.Container.UIReferenceWidth := 1024;
  Window.Container.UIReferenceHeight := 768;
  Window.Container.UIScaling := usEncloseReferenceSize;

  { Load user preferences file.
    You can use it for your own user persistent data
    (preferences or savegames), see
    http://castle-engine.sourceforge.net/tutorial_user_prefs.php . }
  //UserConfig.Load;

  { Standard TCastleWindow (just like analogous Lazarus component TCastleControl)
    gives you a ready instance of SceneManager. SceneManager is a very
    important object in our engine: it contains the whole knowledge about
    your 3D world. In fact, we will use it so often that it's comfortable
    to assign it to a handy variable SceneManager,
    instead of always writing "Window.SceneManager". }
  SceneManager := Window.SceneManager;

  { Load named sounds defined in sounds/index.xml }
  SoundEngine.RepositoryURL := ApplicationData('sounds/index.xml');

  { Load texture properties, used to assign footsteps sounds based
    on ground texture }
  MaterialProperties.URL := ApplicationData('material_properties.xml');

  { Change Theme image tiActiveFrame, used to draw rectangle under image }
  Theme.Images[tiActiveFrame] := LoadImage(ApplicationData('box.png'));
  Theme.OwnsImages[tiActiveFrame] := true;
  Theme.Corners[tiActiveFrame] := Vector4Integer(38, 38, 38, 38);

  { Create extra viewport to observe the 3D world.

    Note that (by default) SceneManager has two functions:
    1.The primary function of SceneManager is to keep track of everything inside
      your 3D world.
    2.In addition, by default it acts as a full-screen viewport
      that allows you to actually see and interact with the 3D world.

    But the 2nd feature (SceneManager as viewport) is completely optional
    and configurable. You can turn it off by SceneManager.DefaultViewport := false.
    Or you can configure size of the viewport by
    by SceneManager.FullSize and SceneManager.Left/Bottom/Width/Height.

    Regardless of this, you can also always add additional viewports by
    TCastleViewport. TCastleViewport refers to the existing SceneManager
    for 3D world information, like below.
    Each viewport has it's own camera, so you can even interact with it
    (the viewport created below uses Examine camera).
    See
    examples/3d_rendering_processing/multiple_viewports and
    examples/2d_standard_ui/zombie_fighter/ for more examples of custom viewports. }
  ExtraViewport := TCastleViewport.Create(Application);
  ExtraViewport.SceneManager := SceneManager;
  ExtraViewport.FullSize := false;
  ExtraViewport.Width := 150;
  ExtraViewport.Height := 400;
  ExtraViewport.Anchor(vpMiddle);
  ExtraViewport.Anchor(hpRight, -ControlsMargin);
  { We insert ExtraViewport to Controls before SceneManager, to be on top. }
  Window.Controls.InsertFront(ExtraViewport);

  { Assign callbacks to some window events.
    Note about initial events: Window.Open calls OnOpen and first OnResize events,
    so if you want to receive them --- be sure to register them before calling
    Window.Open. That is why we assign them here, and that is why we created
    ExtraViewport (that is resized in Resize callback) earlier. }
  Window.OnPress := @Press;

  { Show progress bars on our Window. }
  Progress.UserInterface := WindowProgressInterface;

  { Enable automatic navigation UI on touch devices. }
  //Application.TouchDevice := true; // use this to test touch behavior on desktop
  Window.AutomaticTouchInterface := Application.TouchDevice;

  { Allow player to drop items by "R" key. This shortcut is by default inactive
    (no key/mouse button correspond to it), because not all games may want
    to allow player to do this. }
  Input_DropItem.Assign(K_R);
  if not Application.TouchDevice then
    // allow shooting by clicking or pressing Ctrl key
    Input_Attack.Assign(K_Ctrl, K_None, #0, true, mbLeft);

  { Allow using type="MedKit" inside resource.xml files,
    to define our MedKit item. }
  RegisterResourceClass(TMedKitResource, 'MedKit');

  { Load resources (creatures and items) from resource.xml files. }
  //Resources.LoadFromFiles; // on non-Android, this finds all resource.xml files in data
  Resources.AddFromFile(ApplicationData('knight_creature/resource.xml'));
  Resources.AddFromFile(ApplicationData('item_medkit/resource.xml'));
  Resources.AddFromFile(ApplicationData('item_shooting_eye/resource.xml'));

  { Load available levels information from level.xml files. }
  //Levels.LoadFromFiles; // on non-Android, this finds all level.xml files in data
  Levels.AddFromFile(ApplicationData('example_level/level.xml'));

  { Create player. This is necessary to represent the player as anything
    more than a camera. Player adds inventory, with automatic picking of items
    by default, health (can be hurt by enemies), equipping weapon (a special
    item can be equipped and used to hurt enemies), footsteps and some other
    nice stuff.

    It's best to assign SceneManager.Player before SceneManager.LoadLevel,
    then Player.Camera is automatically configured as SceneManager.Camera
    and it follows level's properties like PreferredHeight (from level's
    NavigationInfo.avatarSize). }
  Player := TPlayer.Create(SceneManager);
  SceneManager.Items.Add(Player);
  SceneManager.Player := Player;

  { Load initial level.
    This loads and adds 3D model of your level to the 3D world
    (that is to SceneManager.Items). It may also load initial creatures/items
    on levels, waypoints/sectors and other information from so-called
    "placeholders" on the level, see TGameSceneManager.LoadLevel documentation. }
  SceneManager.LoadLevel('example_level');

  { Initialize ExtraViewport camera to something
    that nicely views the scene from above. }
  ExtraViewport.NavigationType := ntExamine;
  ExtraViewport.RequiredCamera.SetView(
    { position } Vector3(0, 55, 44),
    { direction } Vector3(0, -1, 0),
    { up } Vector3(0, 0, -1), false
  );
  { Note we allow user to actually edit this view, e.g. by mouse dragging.
    But you could always do this to make camera non-editable: }
  // ExtraViewport.Camera.Input := [];

  { Maybe adjust some rendering properties?
    (SceneManager.MainScene was initialized by SceneManager.LoadLevel) }
  // SceneManager.MainScene.Attributes.PhongShading := true; // per-pixel lighting, everything done by shaders

  { Add some buttons.
    We use TCastleButton from CastleControls unit for buttons,
    which are drawn using OpenGL.
    If you use Lazarus and TCastleControl (instead of TCastleWindow)
    you can also consider using Lazarus standard buttons and other components
    on your form.

    The advantage of our TCastleButton is that it is drawn completely by our
    engine, which means that you can style the TCastleButton to match the theme
    of your game (like medieval fantasy of futuristic sci-fi).
    For now, you can change the colors (see global Theme (instance
    of TCastleTheme class) properties), and also TCastleButton.Opacity.
    Easy way to apply textures on TCastleButton is planned in the future. }
  Buttons := TButtons.Create(Application);

  { Add the Notifications to our window.
    We add a global Notifications object from CastleGameNotifications.
    Of course this is completely optional, you could instead create your own
    TCastleNotifications instance (to not see the default notifications
    made by some engine units) or just don't use notifications at all. }
  Notifications.TextAlignment := hpMiddle;
  Notifications.Anchor(hpMiddle);
  Notifications.Anchor(vpBottom, 5);
  Notifications.Color := Yellow;
  Window.Controls.InsertFront(Notifications);

  { Create and add PlayerHUD to visualize player life, inventory and pain. }
  PlayerHUD := TPlayerHUD.Create(Application);
  Window.Controls.InsertFront(PlayerHUD);

  { Insert default crosshair.
    You can always draw your custom crosshair instead (using TGLImage.Draw
    inside TPlayerHUD, or using TCastleImageControl). }
  Window.Controls.InsertFront(TCastleCrosshair.Create(Application));
end;

function MyGetApplicationName: string;
begin
  Result := 'fps_game';
end;

initialization
  { This unit's initialization *must* initialize Application.MainWindow value.
    Usually it also initializes things related to logging (OnGetApplicationName,
    InitializeLog), because it's beneficial to initialize them as early as possible.

    The rest of initialization should usually be done inside
    Application.OnInitialize callback (ApplicationInitialize in this unit). }

  { OnGetApplicationName should be initialized as early as possible
    to mark our log lines correctly. }
  OnGetApplicationName := @MyGetApplicationName;

  { Enable log.
    See http://castle-engine.sourceforge.net/tutorial_log.php
    to know where it's going. }
  InitializeLog;

  { Create a window. }
  Window := TCastleWindowTouch.Create(Application);

  Application.MainWindow := Window;
  Application.OnInitialize := @ApplicationInitialize;

finalization
  { In a desktop game, it's usually enough to store the preferences
    in the finalization section, when the program stops.
    In mobile games, you should usually store the preferences more often,
    to make sure they are saved even when the program is killed by the OS. }

  { Save the configuration file. This is commented out here,
    as this example program does not give user any UI to actually change
    any configuration.
    Saving prefe }
  //SoundEngine.SaveToConfig(UserConfig);
  //UserConfig.Save;
end.

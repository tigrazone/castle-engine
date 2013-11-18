{ -*- compile-command: "sh compile.sh" -*- }
library castleengine;

uses Math, JNI, CTypes, SysUtils, CastleStringUtils, CastleGLUtils, CastleWindow,
  CastleUIControls, CastleVectors, CastleControls, CastleOnScreenMenu,
  CastleControlsImages, CastleImages, CastleFilesUtils, CastleColors,
  CastleRectangles, CastleAndroidLog, CastleUtils, CastleAndroidNativeActivity,
  CastleAndroidNativeWindow, CastleAndroidRect;

{$ifdef mswindows}
  {$define jniexport := stdcall}
{$else}
  {$define jniexport := cdecl}
{$endif}

var
  Window: TCastleWindow;

type
  T2DControls = class(TUIControl)
  public
    procedure Draw; override;
    function DrawStyle: TUIControlDrawStyle; override;
  end;

function T2DControls.DrawStyle: TUIControlDrawStyle;
begin
  Result := ds2D;
end;

procedure T2DControls.Draw;
begin
  DrawRectangle(Rectangle(
    Application.ScreenWidth - 100,
    Application.ScreenHeight - 100, 80, 80), Blue);
end;

{ See http://developer.android.com/reference/android/opengl/GLSurfaceView.Renderer.html
  for documentation when these methods are called. }

var
  Background: TCastleSimpleBackground;
  MyControl: T2DControls;
  Image: TCastleImageControl;

{ One-time initialization. }
procedure Initialize;
begin
  Window := TCastleWindow.Create(Application);
  Window.SceneManager.Transparent := true;

  Background := TCastleSimpleBackground.Create(Window);
  Background.Color := Yellow;
  Window.Controls.InsertBack(Background);

  MyControl := T2DControls.Create(Window);
  Window.Controls.InsertFront(MyControl);

  Image := TCastleImageControl.Create(Window);
  // TODO: png support
  // TODO: read files using Anroid assets:
  // http://stackoverflow.com/questions/13317387/how-to-get-file-in-assets-from-android-ndk
//    Image.Image := TouchCtlOuter.MakeCopy;
  Image.URL := 'file:///sdcard/kambitest/sample_texture.ppm';
  Window.Controls.InsertFront(Image);

  Window.Load('file:///sdcard/kambitest/castle_with_lights_and_camera.wrl');
end;

procedure OnDestroy(Activity: PANativeActivity); jniexport;
begin
  AndroidLog(alInfo, 'Native Acitivity OnDestroy');
end;

procedure OnStart(Activity: PANativeActivity); jniexport;
begin
  AndroidLog(alInfo, 'Native Acitivity OnStart');
end;

procedure OnStop(Activity: PANativeActivity); jniexport;
begin
  AndroidLog(alInfo, 'Native Acitivity OnStop');
end;

procedure OnPause(Activity: PANativeActivity); jniexport;
begin
  AndroidLog(alInfo, 'Native Acitivity OnPause');
end;

procedure OnResume(Activity: PANativeActivity); jniexport;
begin
  AndroidLog(alInfo, 'Native Acitivity OnResume');
end;

procedure OnNativeWindowCreated(Activity: PANativeActivity; NativeWindow: PANativeWindow); jniexport;
var
  Width, Height: Integer;
begin
  try
    Window.NativeWindow := NativeWindow;
    Width := ANativeWindow_getWidth(NativeWindow);
    Height := ANativeWindow_getHeight(NativeWindow);

    AndroidLog(alInfo, 'Native Acitivity OnNativeWindowCreated (%d %d)', [Width, Height]);

    Application.AndroidInit(Width, Height);

    //Window.FullScreen := true; // sTODO: setting fullscreen should work like that 2 lines below. Also, should be default?
    Window.Width := Width;
    Window.Height := Height;
    Window.Open;
  except
    on E: TObject do AndroidLog(E);
  end;
end;

procedure OnNativeWindowDestroyed(Activity: PANativeActivity; NativeWindow: PANativeWindow); jniexport;
begin
  try
    AndroidLog(alInfo, 'Native Acitivity OnNativeWindowDestroyed');

    { Whenever the context is lost, this is called.
      It's important that we release all OpenGL resources, to recreate them later
      (we wil call Window.Open only from onNativeWindowResized, since we don't know
      the size yet). }
    if Window <> nil then
      Window.Close;

    Window.NativeWindow := nil; // make sure to not access the NativeWindow anymore
  except
    on E: TObject do AndroidLog(E);
  end;
end;

procedure Resize(const CallbackName: string);
var
  Width, Height: Integer;
begin
  try
    Width := ANativeWindow_getWidth(Window.NativeWindow);
    Height := ANativeWindow_getHeight(Window.NativeWindow);

    AndroidLog(alInfo, 'Native Activity %s - %d %d', [CallbackName, Width, Height]);

    if not Window.Closed then
      Window.AndroidResize(Width, Height);

    Image.Left := 10;
    Image.Bottom := Application.ScreenHeight - 300;
  except
    on E: TObject do AndroidLog(E);
  end;
end;

{ On some operations we get both OnNativeWindowResized and OnContentRectChanged,
  on some we get only one of them... For safety, just handle both. }

procedure OnNativeWindowResized(Activity: PANativeActivity; NativeWindow: PANativeWindow); jniexport;
begin
  Resize('OnNativeWindowResized');
end;

procedure OnContentRectChanged(activity: PANativeActivity; Rect: PARect); jniexport;
begin
  Resize('OnContentRectChanged');
end;

procedure OnNativeWindowRedrawNeeded(Activity: PANativeActivity; NativeWindow: PANativeWindow); jniexport;
begin
  try
    AndroidLog(alInfo, 'Native Acitivity OnNativeWindowRedrawNeeded');
    GLClear([cbColor], Green); // first line on Android that worked :)
    Window.AndroidDraw;
  except
    on E: TObject do AndroidLog(E);
  end;
end;

procedure ANativeActivity_onCreate(Activity: PANativeActivity;
  SavedState: Pointer; SavedStateSize: csize_t); jniexport;
begin
  try
    AndroidLog(alInfo, 'ANativeActivity_onCreate');
    Initialize;

    Activity^.Callbacks^.OnDestroy := @OnDestroy;
    Activity^.Callbacks^.OnStart := @OnStart;
    Activity^.Callbacks^.OnStop := @OnStop;
    Activity^.Callbacks^.OnPause := @OnPause;
    Activity^.Callbacks^.OnResume := @OnResume;

    Activity^.Callbacks^.OnNativeWindowCreated := @OnNativeWindowCreated;
    Activity^.Callbacks^.OnNativeWindowDestroyed := @OnNativeWindowDestroyed;
    Activity^.Callbacks^.OnNativeWindowResized := @OnNativeWindowResized;
    Activity^.Callbacks^.OnNativeWindowRedrawNeeded := @OnNativeWindowRedrawNeeded;

    Activity^.Callbacks^.OnContentRectChanged := @OnContentRectChanged;
  except
    on E: TObject do AndroidLog(E);
  end;
end;

exports ANativeActivity_onCreate;

function MyGetApplicationName: string;
begin
  Result := 'cge_android_lib';
end;

begin
  OnGetApplicationName := @MyGetApplicationName;
end.
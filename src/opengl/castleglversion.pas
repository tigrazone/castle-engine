{
  Copyright 2001-2012 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Checking OpenGL version, vendors and such (GLVersion, GLUVersion).

  You must manually initialize GLVersion and such (this unit doesn't even
  use GL bindings). For my engine, this will happen automatically
  at LoadAllExtensions call. Which is done during TCastleWindowBase.Open,
  or TCastleControlCustom on GL context initialization.
}
unit CastleGLVersion;

interface

type
  { OpenGL libraries (core OpenGL or GLU) version information.

    As obtained from glGetString(GL_VERSION)
    or gluGetString(GLU_VERSION), also by glGetString(GL_VENDOR).

    This is usually created by CastleGLUtils.LoadAllExtensions. }
  TGenericGLVersion = class
  public
    constructor Create(const VersionString: string);
  public
    { Required (every OpenGL implemenetation has them)
      major and minor numbers.
      @groupBegin }
    Major: Integer;
    Minor: Integer;
    { @groupEnd }

    { Release is the optional release number (check ReleaseExists first).
      @groupBegin }
    ReleaseExists: boolean;
    Release: Integer;
    { @groupEnd }

    { VendorVersion is whatever vendor-specific information was placed
      inside VersionString, after the
      major_number.minor_number.release_number. It never has any whitespace
      at the beginning (we trim it when initializing). }
    VendorVersion: string;

    function AtLeast(AMajor, AMinor: Integer): boolean;
  end;

  TGLVersion = class(TGenericGLVersion)
  private
    FVendor: string;
    FRenderer: string;
    FVendorATI: boolean;
    FFglrx: boolean;
    FVendorNVidia: boolean;
    FVendorIntel: boolean;
    FMesa: boolean;
    FMesaMajor: Integer;
    FMesaMinor: Integer;
    FMesaRelease: Integer;
    FBuggyPointSetAttrib: boolean;
    FBuggyDrawOddWidth: boolean;
    FBuggyGenerateMipmap: boolean;
    FBuggyGenerateCubeMap: boolean;
    FBuggyFBOCubeMap: boolean;
    FBuggyLightModelTwoSide: boolean;
    FBuggyLightModelTwoSideMessage: string;
    FBuggyVBO: boolean;
    FBuggyShaderShadowMap: boolean;
    FBuggyGLSLConstStruct: boolean;
    FBuggyFBOMultiSampling: boolean;
  public
    constructor Create(const VersionString, AVendor, ARenderer: string);

    { Vendor that created the OpenGL implemenetation.
      This is just glGetString(GL_VENDOR). }
    property Vendor: string read FVendor;

    { Renderer (GPU model, or software method used for rendering) of the OpenGL.
      This is just glGetString(GL_RENDERER). }
    property Renderer: string read FRenderer;

    { Are we using Mesa (http://mesa3d.org/).
      Detected using VendorSpecific information
      (extracted by base TGenericGLVersion), this allows us to also detect
      Mesa version.
      @groupBegin }
    property Mesa: boolean read FMesa;
    property MesaMajor: Integer read FMesaMajor;
    property MesaMinor: Integer read FMesaMinor;
    property MesaRelease: Integer read FMesaRelease;
    { @groupEnd }

    { ATI GPU with ATI drivers. }
    property VendorATI: boolean read FVendorATI;

    { ATI GPU with ATI drivers on Linux. }
    property Fglrx: boolean read FFglrx;

    { NVidia GPU with NVidia drivers. }
    property VendorNVidia: boolean read FVendorNVidia;

    { Intel GPU with Intel drivers. }
    property VendorIntel: boolean read FVendorIntel;

    { Buggy GL_POINT_BIT flag for glPushAttrib (Mesa DRI Intel bug).

      Observed on Ubuntu 8.10 on computer "domek".
      It seems a bug in upstream Mesa 7.2, as it's reproducible with
      version from http://mesa3d.org/.
      Seemingly reproducible only with "DRI Intel"
      (not reproducible on "chantal" with upstream Mesa 7.2).

      Reported to Ubuntu as
      https://bugs.launchpad.net/ubuntu/+source/mesa/+bug/312830,
      let them report upstream if needed.
      Not observed with Mesa 7.6 in Ubuntu 10.4. }
    property BuggyPointSetAttrib: boolean read FBuggyPointSetAttrib;

    { Buggy drawing of images with odd width (fglrx (ATI on Linux) bug).

      I observe this under Debian testing after upgrading fglrx
      from 8-12-4 to 9-2-2. I know the bug wasn't present in 8-12-4
      (and some other < 8-12-4 that I previously used), and it is in 9-2-2.

      I also see this on Mac OS X with the same GPU (driver GL_VERSION:
      2.0 ATI-1.4.56, GL_RENDERER: ATI Radeon X1600 OpenGL Engine).
      Although it's less common on Mac OS X, but can be seen with
      demo_models/x3d/rendered_texture.x3dv:
      open it, then make some operation that saves screen,
      e.g. open dialog by Ctrl+O.

      Precisely, the problem is for images with size like 819 x 614.
      Drawing them by glDrawPixels (including the case when you put
      this in display list) requires glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
      (as our TRGBImage is not aligned). And on GPUs with
      BuggyDrawOddWidth, such glDrawPixels will simply draw a random
      mess of colors on the screen, like some memory garbage.
      (Note that the image is actually correct, even capturing it
      by glReadPixels works Ok; only drawing of it fails.)

      As far as I tested, this doesn't seem related to
      actual GL_UNPACK_ALIGNMENT (glPixelStorei(GL_UNPACK_ALIGNMENT, 4)
      may also produce the bug, e.g. when used with ImageDrawPart
      trying to draw subimage with odd width). }
    property BuggyDrawOddWidth: boolean read FBuggyDrawOddWidth;

    { Buggy glGenerateMipmapEXT (Mesa and Intel(Windows) bug).

      This was observed with software (no direct) rendering with
      7.0.2 (segfaults) and 7.2.? (makes X crashing; sweet).
      With Mesa 7.5.1 (but tested only with radeon and radeonhd,
      so possibly it's not really related to Mesa version! Reports welcome)
      no problems. }
    property BuggyGenerateMipmap: boolean read FBuggyGenerateMipmap;

    { Buggy generation of cube maps on FBO (Intel(Windows) bug).

      Symptoms: Parts of the cube map texture are uninitialized (left magenta).
      Reproducible with view3dscene on
      demo_models/cube_environment_mapping/cubemap_generated_in_dynamic_world.x3dv .
      Using separate FBO for each cube map face doesn't help (actually,
      makes it worse, there's more magenta),
      so it's not about being unable to do RenderToTexture.SetTexture multiple times.

      Observed, and this workaround is needed, at least on:
      @unorderedList(
        @item Version string: 2.1.0 - Build 8.15.10.2104
        @item Vendor: Intel
        @item Renderer: Intel(R) HD Graphics
      )
    }
    property BuggyFBOCubeMap: boolean read FBuggyFBOCubeMap;

    { Buggy generation of cube maps at all (Intel(Windows) bug).

      Symptoms: Parts of the cube map texture are uninitialized (left magenta).
      Reproducible with view3dscene on
      demo_models/cube_environment_mapping/cubemap_generated_in_dynamic_world.x3dv .
      This is worse then BuggyFBOCubeMap, magenta is always seen at positiveX part
      of the cube map.

      Observed, and this workaround is needed, at least on:
      @unorderedList(
        @item Version string: 3.3.0 - Build 8.15.10.2778
        @item Vendor: Intel
        @item Renderer: Intel(R) HD Graphics 4000
      )
    }
    property BuggyGenerateCubeMap: boolean read FBuggyGenerateCubeMap;

    { Buggy GL_LIGHT_MODEL_TWO_SIDE = GL_TRUE behavior (ATI(Linux) bug).
      See [https://sourceforge.net/apps/phpbb/vrmlengine/viewtopic.php?f=3&t=14] }
    property BuggyLightModelTwoSide: boolean read FBuggyLightModelTwoSide;
    property BuggyLightModelTwoSideMessage: string read FBuggyLightModelTwoSideMessage;

    { Buggy VBO (Intel(Windows) bug). }
    property BuggyVBO: boolean read FBuggyVBO;

    { Buggy shadow2DProj in some situations (ATI(Linux) bug). }
    property BuggyShaderShadowMap: boolean read FBuggyShaderShadowMap;

    { Buggy GLSL @code("const in gl_Xxx") (NVidia bug).
      Segfaults at glCompileShader[ARB] on GLSL declarations like
      @code("const in gl_MaterialParameters material").
      Affects some NVidia drivers on Linux (like version 295.49
      in Debian testing on 2012-06-02). }
    property BuggyGLSLConstStruct: boolean read FBuggyGLSLConstStruct;

    { Buggy (looks like wireframe) FBO rendering to
      the multi-sampling texture (ATI(Windows) and Intel(Windows) bug).
      This makes our screen effects broken on multi-sampled contexts. }
    property BuggyFBOMultiSampling: boolean read FBuggyFBOMultiSampling;
  end;

var
  { Core OpenGL version information.
    This is usually created by CastleGLUtils.LoadAllExtensions. }
  GLVersion: TGLVersion;

  { GLU version information.
    This is usually created by CastleGLUtils.LoadAllExtensions. }
  GLUVersion: TGenericGLVersion;

implementation

uses SysUtils, CastleStringUtils, CastleUtils;

{ TGenericGLVersion ---------------------------------------------------------- }

type
  EInvalidGLVersionString = class(Exception);

procedure ParseWhiteSpaces(const S: string; var I: Integer);
begin
  while SCharIs(S, I, WhiteSpaces) do Inc(I);
end;

constructor TGenericGLVersion.Create(const VersionString: string);
const
  Digits = ['0'..'9'];
var
  NumberBegin, I: Integer;
begin
  inherited Create;

  try
    I := 1;

    { Note: we allow some whitespace that is not allowed by OpenGL/GLU
      spec. That's because we try hard to work correctly even with
      broken GL_VERSION / GLU_VERSION strings. }

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    { Major number }
    if not SCharIs(VersionString, I, Digits) then
      raise EInvalidGLVersionString.Create('Major version number not found');
    NumberBegin := I;
    while SCharIs(VersionString, I, Digits) do Inc(I);
    Major := StrToInt(CopyPos(VersionString, NumberBegin, I - 1));

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    { Dot }
    if not SCharIs(VersionString, I, '.') then
      raise EInvalidGLVersionString.Create(
        'The dot "." separator major and minor version number not found');
    Inc(I);

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    { Minor number }
    if not SCharIs(VersionString, I, Digits) then
      raise EInvalidGLVersionString.Create('Minor version number not found');
    NumberBegin := I;
    while SCharIs(VersionString, I, Digits) do Inc(I);
    Minor := StrToInt(CopyPos(VersionString, NumberBegin, I - 1));

    ReleaseExists := SCharIs(VersionString, I, '.');

    if ReleaseExists then
    begin
      { Dot }
      Inc(I);

      { Release number }
      if not SCharIs(VersionString, I, Digits) then
      raise EInvalidGLVersionString.Create(
        'Release version number not found, ' +
        'although there was a dot after minor number');
      NumberBegin := I;
      while SCharIs(VersionString, I, Digits) do Inc(I);
      Release := StrToInt(CopyPos(VersionString, NumberBegin, I - 1));
    end;

    { Whitespace }
    ParseWhiteSpaces(VersionString, I);

    VendorVersion := SEnding(VersionString, I);
  except
    { In case of any error here: silence it.
      So actually EInvalidGLVersionString is not useful.
      We want our program to work even with broken GL_VERSION or GLU_VERSION
      strings.

      Class constructor always starts with Major and Minor initialized
      to 0, ReleaseExists initialized to false, and VendorVersion to ''.
      If we have here an exception, only part of them may be initialized. }
  end;
end;

function TGenericGLVersion.AtLeast(AMajor, AMinor: Integer): boolean;
begin
  Result := (AMajor < Major) or
    ( (AMajor = Major) and (AMinor <= Minor) );
end;

{ TGLVersion ----------------------------------------------------------------- }

constructor TGLVersion.Create(const VersionString, AVendor, ARenderer: string);

  { Parse Mesa version, starting from S[I] (where I should
    be the index in S right after the word "Mesa"). }
  procedure ParseMesaVersion(const S: string; var I: Integer);
  const
    Digits = ['0'..'9'];
  var
    NumberBegin: Integer;
  begin
    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Mesa major number }
    if not SCharIs(S, I, Digits) then
      raise EInvalidGLVersionString.Create('Mesa major version number not found');
    NumberBegin := I;
    while SCharIs(S, I, Digits) do Inc(I);
    FMesaMajor := StrToInt(CopyPos(S, NumberBegin, I - 1));

    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Dot }
    if not SCharIs(S, I, '.') then
      raise EInvalidGLVersionString.Create(
        'The dot "." separator between Mesa major and minor version number not found');
    Inc(I);

    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Mesa minor number }
    if not SCharIs(S, I, Digits) then
      raise EInvalidGLVersionString.Create('Mesa minor version number not found');
    NumberBegin := I;
    while SCharIs(S, I, Digits) do Inc(I);
    FMesaMinor := StrToInt(CopyPos(S, NumberBegin, I - 1));

    { Whitespace }
    ParseWhiteSpaces(S, I);

    { Dot }
    if SCharIs(S, I, '.') then
    begin
      Inc(I);

      { Whitespace }
      ParseWhiteSpaces(S, I);

      { Mesa release number }
      if not SCharIs(S, I, Digits) then
        raise EInvalidGLVersionString.Create('Mesa release version number not found');
      NumberBegin := I;
      while SCharIs(S, I, Digits) do Inc(I);
      FMesaRelease := StrToInt(CopyPos(S, NumberBegin, I - 1));
    end else
    begin
      { Some older Mesa versions (like 5.1) and newer (7.2) really
        don't have release number inside a version string.
        Seems like they don't have
        release number at all, and assuming "0" seems sensible following
        version names on WWW. So the missing dot "."
        separator between Mesa minor and release version number should
        be ignored. }
      FMesaRelease := 0;
    end;
  end;

  function MesaVersionAtLeast(VerMaj, VerMin, VerRel: Integer): boolean;
  begin
    Result :=
        (MesaMajor > VerMaj) or
      ( (MesaMajor = VerMaj) and (

        (MesaMinor > VerMin) or
      ( (MesaMinor = VerMin) and (

         MesaRelease >= VerRel
      ))));
  end;

var
  VendorName, S: string;
  MesaStartIndex, I: Integer;
begin
  inherited Create(VersionString);

  try
    I := 1;
    while SCharIs(VendorVersion, I, AllChars - WhiteSpaces) do Inc(I);

    VendorName := CopyPos(VendorVersion, 1, I - 1);
    FMesa := SameText(VendorName, 'Mesa');
    if Mesa then
      ParseMesaVersion(VendorVersion, I) else
    begin
      { I'm seeing also things like GL_VERSION = 1.4 (2.1 Mesa 7.0.4)
        (Debian testing (lenny) on 2008-12-31).
        So "Mesa" may be within parenthesis, preceeded by another version
        number. }
      if SCharIs(VendorVersion, 1, '(') and
         (VendorVersion[Length(VendorVersion)] = ')') then
      begin
        S := Copy(VendorVersion, 2, Length(VendorVersion) - 2);
        I := 1;

        { omit preceeding version number }
        while SCharIs(S, I, AllChars - WhiteSpaces) do Inc(I);

        { omit whitespace }
        ParseWhiteSpaces(S, I);

        { read "Mesa" (hopefully) string }
        MesaStartIndex := I;
        while SCharIs(S, I, AllChars - WhiteSpaces) do Inc(I);

        VendorName := CopyPos(S, MesaStartIndex, I - 1);
        FMesa := SameText(VendorName, 'Mesa');
        if Mesa then
          ParseMesaVersion(S, I);
      end;
    end;

  except
    { Just like in TGenericGLVersion: in case of trouble (broken GL_VERSION
      string) ignore the problem. }
  end;

  FVendor := AVendor;
  FRenderer := ARenderer;

  { Actually seen possible values here: 'NVIDIA Corporation'. }
  FVendorNVidia := IsPrefix('NVIDIA', Vendor);

  { Although "ATI Technologies Inc." is usually found,
    according to http://delphi3d.net/hardware/listreports.php
    also just "ATI" is possible. }
  FVendorATI := (Vendor = 'ATI Technologies Inc.') or (Vendor = 'ATI');
  FFglrx := {$ifdef LINUX} VendorATI {$else} false {$endif};

  FVendorIntel := IsPrefix('Intel', Vendor);

  FBuggyPointSetAttrib := Mesa and IsPrefix('Mesa DRI Intel', Renderer)
    and (not MesaVersionAtLeast(7, 6, 0));

  { Initially, I wanted to set this when fglrx version 9.x is detected.

    This can be detected by looking at the last number in GL_VERSION,
    it's an internal fglrx version number (9.x is an "official" Catalyst
    version). Looking at http://www2.ati.com/drivers/linux/catalyst_91_linux.pdf
    (linked from http://wiki.cchtml.com/index.php/Catalyst_9.1)
    the 9.1 release corresponds to internal number 8.573,
    which I think is encoded directly in Release number we have here.

    Later: I'll just do this do every ATI, since Mac OS X GPU has the same
    problem on rendered_texture.x3dv test. }
  FBuggyDrawOddWidth := VendorATI;

  FBuggyGenerateMipmap := (Mesa and (not MesaVersionAtLeast(7, 5, 0)))
                          {$ifdef WINDOWS} or VendorIntel {$endif};

  FBuggyFBOCubeMap := {$ifdef WINDOWS} VendorIntel {$else} false {$endif};

  FBuggyGenerateCubeMap := {$ifdef WINDOWS} (VendorIntel and SameText(Renderer, 'Intel(R) HD Graphics 4000')) {$else} false {$endif};
  { On which fglrx versions does this occur?

    - On Catalyst 8.12 (fglrx 8.561) all seems to work fine
      (tested on MacBook Pro "chantal").

    - Catalyst 9.1 (fglrx 8.573) - not known.
      Below we only *assume* the bug started from 9.1.

    - On Catalyst 9.10 and 10.3 the bug does occur.
      Tested on Radeon HD 4300 (on HP ProBook "czarny"), Ubuntu x86_64.

    - Bug confirmed also on Ubuntu 10.04 (fglrx 8.723).
      Tested on Radeon HD 4300 (on HP ProBook "czarny"), Ubuntu x86_64.

    - Bug disappeared on Ubuntu 10.10 (fglrx 8.780). Seems fixed there.
      (fglrx bugzilla was wiped, so we don't have any official
      confirmation about this from AMD.) }

  FBuggyLightModelTwoSide := Fglrx and ReleaseExists and
    (Release >= 8573) and (Release < 8780);
  if BuggyLightModelTwoSide then
    FBuggyLightModelTwoSideMessage := 'Detected fglrx (ATI proprietary Linux drivers) version >= 9.x. ' + 'Setting GL_LIGHT_MODEL_TWO_SIDE to GL_TRUE may cause nasty bugs on some shaders (see http://sourceforge.net/apps/phpbb/vrmlengine/viewtopic.php?f=3&t=14), so disabling two-sided lighting.' else
    FBuggyLightModelTwoSideMessage := '';

  FBuggyVBO := {$ifdef WINDOWS}
    { See demo_models/x3d/background_test_mobile_intel_gpu_bugs.x3d }
    (Vendor = 'Intel') and
    (Renderer = 'Intel Cantiga') and
    (not AtLeast(1, 6))
    {$else}
    false
    {$endif};

  FBuggyShaderShadowMap :=
    { This happens on fglrx, the worst OpenGL driver in the world.
      card: ATI Mobility Radeon HD 4300,
      confirmed on
        Ubuntu 10.10/x86_64 (czarny)
        Ubuntu 10.10/i386   (czarny)
        Ubuntu 11.4/x86_64  (czarny)
        Ubuntu 11.4/i386    (czarny) (fglrx OpenGL version 3.3.10665)
      not occurs on
        Ubuntu 9.10/i386    (czarny)
      Looks like fglrx bug since at least Ubuntu 10.10 (assuming always
      since Ubuntu 10.04, which is fglrx >= 8.723). }
    Fglrx and ReleaseExists and (Release >= 8723);

  FBuggyGLSLConstStruct := {$ifdef LINUX} VendorNvidia {$else} false {$endif};

   { Reported on Radeon 6600, 6850 - looks like wireframe
     Also on Intel cards - querying multisampled depth buffer returns bad data. }
  FBuggyFBOMultiSampling :=
    {$ifdef WINDOWS} (VendorATI and
      (IsPrefix('AMD Radeon HD 6', Renderer) or IsPrefix('AMD Radeon HD6', Renderer)))
    or VendorIntel
    {$else} false {$endif};
end;

finalization
  FreeAndNil(GLVersion);
  FreeAndNil(GLUVersion);
end.
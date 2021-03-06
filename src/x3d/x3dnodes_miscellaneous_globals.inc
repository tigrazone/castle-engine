{
  Copyright 2002-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{$ifdef read_interface}

const
  ProjectionTypeToStr: array [TProjectionType] of string =
  ('Orthographic', 'Perspective', 'Frustum');

  DefaultMaterial_1AmbientColor: TVector3 = (Data: (0.2, 0.2, 0.2)) deprecated 'use TMaterialInfo.DefaultAmbientColor';
  DefaultMaterialAmbientIntensity = 0.2 deprecated 'use TMaterialInfo.DefaultAmbientIntensity';
  DefaultMaterialDiffuseColor: TVector3 = (Data: (0.8, 0.8, 0.8)) deprecated 'use TMaterialInfo.DefaultDiffuseColor';
  DefaultMaterialSpecularColor: TVector3 = (Data: (0, 0, 0)) deprecated 'use TMaterialInfo.DefaultSpecularColor';
  DefaultMaterialEmissiveColor: TVector3 = (Data: (0, 0, 0)) deprecated 'use TMaterialInfo.DefaultEmissiveColor';
  DefaultMaterialShininess = 0.2 deprecated 'use TMaterialInfo.DefaultShininess';
  DefaultMaterialTransparency = 0.0 deprecated 'use TMaterialInfo.DefaultTransparency';
  DefaultMaterialMirror = 0.0 deprecated 'use TMaterialInfo.DefaultMirror';
  DefaultMaterialReflSpecularExp = 1000000 deprecated 'use TMaterialInfo.DefaultReflSpecularExp';
  DefaultMaterialTransSpecularExp = 1000000 deprecated 'use TMaterialInfo.DefaultTransSpecularExp';

  { Constants for @link(TAsciiTextNode_1.FdJustification).Value.
    @groupBegin }
  JUSTIFICATION_LEFT = 0 deprecated 'use fjBegin (from an enumerated type TX3DFontJustify) with TAsciiTextNode_1.Justify or TFontStyleNode.Justify properties';
  JUSTIFICATION_CENTER = 1 deprecated 'use fjMiddle (from an enumerated type TX3DFontJustify) with TAsciiTextNode_1.Justify or TFontStyleNode.Justify properties';
  JUSTIFICATION_RIGHT = 2 deprecated 'use fjEnd (from an enumerated type TX3DFontJustify) with TAsciiTextNode_1.Justify or TFontStyleNode.Justify properties';
  { @groupEnd }

  { Constants for
    @link(TMaterialBindingNode_1.FdValue).Value and
    @link(TNormalBindingNode_1.FdValue).Value.
    @groupBegin }
  BIND_DEFAULT = 0;
  BIND_OVERALL = 1;
  BIND_PER_PART = 2;
  BIND_PER_PART_INDEXED = 3;
  BIND_PER_FACE = 4;
  BIND_PER_FACE_INDEXED = 5;
  BIND_PER_VERTEX = 6;
  BIND_PER_VERTEX_INDEXED = 7;
  { @groupEnd }

  { Constants for @link(TShapeHintsNode_1.FdVertexOrdering).Value.
    @groupBegin }
  VERTORDER_UNKNOWN = 0;
  VERTORDER_CLOCKWISE = 1;
  VERTORDER_COUNTERCLOCKWISE = 2;
  { @groupEnd }

  { Constants for @link(TShapeHintsNode_1.FdShapeType).Value.
    @groupBegin }
  SHTYPE_UNKNOWN = 0;
  SHTYPE_SOLID = 1;
  { @groupEnd }

  { Constants for @link(TShapeHintsNode_1.FdFaceType).Value.
    @groupBegin }
  FACETYPE_UNKNOWN = 0;
  FACETYPE_CONVEX = 1;
  { @groupEnd }

  { Constants for @link(TFontStyleNode.FdFamily).Value.
    @groupBegin }
  FSFAMILY_SERIF = 0 deprecated 'use ffSerif (TX3DFontFamily an enumerated type) with the properties like TFontStyleNode.Family';
  FSFAMILY_SANS = 1 deprecated 'use ffSans (TX3DFontFamily an enumerated type) with the properties like TFontStyleNode.Family';
  FSFAMILY_TYPEWRITER = 2 deprecated 'use ffTypeWriter (TX3DFontFamily an enumerated type) with the properties like TFontStyleNode.Family';
  { @groupEnd }

  { Constants for VRML 1.0 @link(TFontStyleNode_1.FdStyle) flags.
    @groupBegin }
  FSSTYLE_BOLD = 0 deprecated 'use TFontStyleNode.Bold as a simple boolean';
  FSSTYLE_ITALIC = 1 deprecated 'use TFontStyleNode.Italic as a simple boolean';
  { @groupEnd }

  { Constants for TConeNode.FdParts.Flags.
    @groupBegin }
  CONE_PARTS_SIDES = 0;
  CONE_PARTS_BOTTOM = 1;
  { @groupEnd }

  { Constants for TCylinderNode.FdParts.Flags.
    @groupBegin }
  CYLINDER_PARTS_SIDES = 0;
  CYLINDER_PARTS_TOP = 1;
  CYLINDER_PARTS_BOTTOM = 2;
  { @groupEnd }

  { Constants for @link(TTexture2Node_1.FdWrapS).Value and @link(TTexture2Node_1.FdWrapT).Value.
    @groupBegin }
  TEXWRAP_REPEAT = 0 deprecated 'use TAbstractTexture2DNode.RepeatS or TAbstractTexture2DNode.RepeatT boolean properties';
  TEXWRAP_CLAMP = 1 deprecated 'use TAbstractTexture2DNode.RepeatS or TAbstractTexture2DNode.RepeatT boolean properties';
  { @groupEnd }

  DefaultHeightMapScale = 0.01;
  DefaultVRML1CreaseAngle = 0.5;

  DefaultViewpointFieldOfView = Pi / 4;
  DefaultNavigationInfoHeadlight = true;

  DefaultRenderedTextureWidth  = 128;
  DefaultRenderedTextureHeight = 128;

  VRML1Version: TX3DVersion = (Major: 1; Minor: 0);
  VRML2Version: TX3DVersion = (Major: 2; Minor: 0);
  { Latest X3D version supported. }
  X3DVersion: TX3DVersion = (Major: 3; Minor: 2);

  xeClassic = CastleInternalX3DLexer.xeClassic;
  xeXML = CastleInternalX3DLexer.xeXML;

  { Minimal values for
    @link(DefaultTriangulationSlices),
    @link(DefaultTriangulationStacks),
    @link(DefaultTriangulationDivisions).

    Note that MinTriangulationSlices can be lower (2), it works,
    but the result isn't really sensible.
    @groupBegin }
  MinTriangulationSlices: Cardinal = 3;
  MinTriangulationStacks: Cardinal = 1;
  MinTriangulationDivisions: Cardinal = 0;
  { @groupEnd }

  { Classes corresponding to nodes on TVRML1State. }
  VRML1StateClasses: array [TVRML1StateNode] of TX3DNodeClass = (
    TCoordinate3Node_1,
    TShapeHintsNode_1,
    TFontStyleNode_1,
    TMaterialNode_1,
    TMaterialBindingNode_1,
    TNormalNode,
    TNormalBindingNode_1,
    TTexture2Node_1,
    TTextureCoordinate2Node_1
    { additions here must be synchronized with additions to TVRML1State }
  );

var
  { Triangulation settings.

    "Slices" divide the circumference of the circle, like the slices of a pizza.
    "Stacks" divide the height of the object, like the stacks of a cake or tower.
    These are used for quadrics - cylinder, cone, sphere and disk.

    "Divisions" divide the cube side.
    This is beneficial for better Gouraud shading.

    You can change these variables only @italic(before using anything)
    from this module. If you want to change them inside VRML/X3D
    file (for example, to affect only part of the scene), use the
    Triangulation node, see
    http://castle-engine.sourceforge.net/x3d_implementation_geometry3d_extensions.php#section_triangulation

    These variables @italic(must) always honour
    @link(MinTriangulationSlices),
    @link(MinTriangulationStacks),
    @link(MinTriangulationDivisions) limits.

    @groupBegin }
  DefaultTriangulationSlices: Cardinal = 30;
  DefaultTriangulationStacks: Cardinal = 20;
  DefaultTriangulationDivisions: Cardinal = 2;
  { @groupEnd }

const
  { URNs used to indicate standard VRML / X3D nodes.

    Funny thing, I actually didn't found anywhere a definite official
    statement that they are using such-and-such URNs.

    X3D specification refers to RFC
    [http://www.ietf.org/rfc/rfc3541.txt?number=3541] which, basically,
    just says "we like URNs and we'll use them" and nothing more.
    Same thing for VRML 97 spec
    [http://www.web3d.org/x3d/specifications/vrml/ISO-IEC-14772-VRML97/part1/extensions.html].
    There is no precise answer e.g. what URN should be used to
    Indicate some standard VRML 97 / X3D node.

    I constructed URNs below looking at examples in the RFC,
    annotated by a funny line "The following examples are not
    guaranteed to be real. They are presented for pedagogical reasons only."

    @groupBegin }
  URNVRML97Nodes = 'urn:web3d:vrml97:node:';
  URNX3DNodes = 'urn:web3d:x3d:node:';
  { @groupEnd }

  { URN to indicate BitManagement nodes. This should work, according to
    http://www.bitmanagement.com/developer/contact/examples/layer/index.html
    example EXTERNPROTO. }
  URNBitManagementNodes = 'urn:inet:bitmanagement.de:node:';

  { Standard prefix name for a time sensor to be recognized as a "named animation"
    for TCastleSceneCore.PlayAnimation and friends. }
  DefaultAnimationPrefix = '';

  AllAccessTypes = [atInputOnly, atOutputOnly, atInitializeOnly, atInputOutput];
  RestrictedAccessTypes = [atInputOnly, atOutputOnly, atInitializeOnly];

var
  { Functions registered here will be called when any TX3DNode descendant
    will be destroyed. }
  AnyNodeDestructionNotifications: TNodeDestructionNotificationList;

  { Cache, for all the resources not tied with renderer context. }
  X3DCache: TX3DNodesCache;

  { Should we emit a warning when loading data from
    an URI with an absolute filename, like @code(file:///c:/blah/myimage.png).
    The warning is emitted using WritelnWarning.
    This is quite useful, as usually you want to avoid using such URIs,
    as they will probably not work on any other system than your own
    (and they prevent you from easily moving the files to some other system/location).

    In your data (X3D, VRML, Collada, OBJ materials...),
    you should always use relative paths. }
  WarnAboutAbsoluteFilenames: boolean = true;

{ Free all unused VRML/X3D nodes on the list, then free and @nil the list
  itself. }
procedure X3DNodeList_FreeUnusedAndNil(var List: TX3DNodeList);

{ Find a range within "key" field corresponding to given Fraction.
  Returns the index of @bold(right) range delimiter.
  So for normal ranges (between two values of "key" field) it's
  always between 1 and FdKey.Count - 1. Result 0 indicates we're
  before the left limit, and result equal FdKey.Count indicates
  we're after right limit.

  Result is always between 0 and FdKey.Count.

  Output T is the value between 0..1 indicating where within
  the range we are. It's undefined when Result is 0 or Key.Count
  (indicating we're outside limits).

  Call this only when FdKey.Count > 0.

  This is useful to interpreting TAbstractInterpolatorNode.KeyRange
  and such fields. }
function KeyRange(Key: TSingleList;
  const Fraction: Single; out T: Single): Integer;

{ Free TX3DNode if it is unused (see TX3DNode.FreeIfUnused),
  setting reference to @nil. Analogous to standard FreeAndNil,
  but checks if node is used first. }
procedure FreeIfUnusedAndNil(var Obj);

{ Does this URN indicate an X3D node that is a Castle Game Engine extension.
  This is a helper for implementing @link(TX3DNode.URNMatching). }
function URNMatchingCastle(const URN, ClassX3DType: string): boolean;

{$endif read_interface}

{$ifdef read_implementation}

procedure X3DNodeList_FreeUnusedAndNil(var List: TX3DNodeList);
var
  I: Integer;
begin
  if List <> nil then
  begin
    for I := 0 to List.Count - 1 do
      if List.Items[I].VRML1ParentsCount + List.Items[I].ParentFieldsCount = 0 then
        List.Items[I].Free;
    FreeAndNil(List);
  end;
end;

function KeyRange(Key: TSingleList;
  const Fraction: Single; out T: Single): Integer;
var
  A, B: Integer;
begin
  Assert(Key.Count > 0);
  Assert(not IsNan(Fraction));

  if Fraction <= Key.First then
    Result := 0 else
  if Fraction >= Key.Last then
    Result := Key.Count else
  begin
    { Then for sure we're between two Key values.
      Note that we know that Key.Count > 1 (otherwise, Key.First = Key.Last
      so one of <= or >= comparisons above would occur; we check
      IsNan(Fraction) at the beginning to eliminate Fraction=NaN case). }
    Assert(Key.Count > 1);

    { Always A < B.
      We're considering range from Key[A] to Key[B].

      Remember that we cannot actually depend on the fact that
      Key values are non-decreasing. They should be non-decreasing,
      and we have to output correct result only when they are non-decreasing,
      but we also have to terminate (with any result) in any situation.
      Reason: Key values are supplied in X3D file, so they may be broken
      in every possible way. }

    A := 0;
    B := Key.Count - 1;
    while B - A > 1 do
    begin
      Result := (A + B) div 2;
      { A < B => (A + B) < 2B => (A + B) div 2 < B => Result < B.
        Also, Result > A (the only way how Result could be = A
        would be when B = A + 1, but we eliminated this case by "while"
        condition".

        This is good, it means A < Result < B, so Result is good candidate
        for next A or B, it will for sure shorten the distance
        between A and B. }
      Assert(A < Result);
      Assert(Result < B);
      { Using "<" instead of "<=" below: when the Fraction = Key[Result],
        we want to go to right part, not left. See
        - X3D specification
          http://www.web3d.org/documents/specifications/19775-1/V3.3/Part01/components/utils.html#SequencingEvents
          It says that f(t) = vn, if tn <= t < tn-1
        - Testcase on https://github.com/castle-engine/view3dscene/issues/2
      }
      if Fraction < Key[Result] then
        B := Result else
        A := Result;
    end;
    Result := B;

    if Key[B] > Key[A] then
      T := (Fraction - Key[A]) / (Key[B] - Key[A])
    else
      T := 0;
  end;
end;

procedure FreeIfUnusedAndNil(var Obj);
var
  Temp: TX3DNode;
begin
  Temp := TX3DNode(Obj);
  Pointer(Obj) := nil;
  Temp.FreeIfUnused;
end;

function URNMatchingCastle(const URN, ClassX3DType: string): boolean;
begin
  Result :=
    (URN = 'urn:castle-engine.sourceforge.io:node:' + ClassX3DType) or
    (URN = 'urn:castle-engine.sourceforge.net:node:' + ClassX3DType) or
    (URN = 'urn:vrmlengine.sourceforge.net:node:' + ClassX3DType);
end;

{$endif read_implementation}

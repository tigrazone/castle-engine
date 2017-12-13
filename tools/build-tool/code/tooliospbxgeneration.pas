{
  Copyright 2017-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Generation of the pbxproj project file, part of the iOS XCode project. }
unit ToolIosPbxGeneration;

interface

uses SysUtils, Generics.Collections,
  CastleFindFiles;

type
  TXCodeProjectFile = class;
  TXCodeProject = class;

  TXCodeProjectFileList = specialize TObjectList<TXCodeProjectFile>;

  { Framework within an XCode project. }
  TXCodeProjectFramework = class
    Name: string;
    FileUuid, BuildUuid: string;
    constructor Create(const AName: string);
  end;

  { File or directory within an XCode project. }
  TXCodeProjectFile = class
    Name: string;
    FileUuid, BuildUuid: string;
    { Children references.
      List instance itself is owned, but items on this list are not owned by this object. }
    Children: TXCodeProjectFileList;
    Directory: boolean;
    Project: TXCodeProject;
    constructor Create; overload;
    constructor Create(const FileInfo: TFileInfo); overload;
    destructor Destroy; override;
    function FileType: string;
    function BuildGroup: string;
    procedure AddChildFile(const FileInfo: TFileInfo; var StopSearch: boolean);
  end;

  TXCodeProjectFrameworkList = specialize TObjectList<TXCodeProjectFramework>;

  { XCode project things (files, frameworks...) information,
    useful to generate xxx.pbxproj file. }
  TXCodeProject = class
  strict private
    TopLevelDir: TXCodeProjectFile;

    function SectionPBXFileReference: string;
    function SectionPBXBuildFile: string;
    function SectionPBXGroup: string;

    function SectionPBXFrameworksBuildPhase: string;
    function SectionPBXResourcesBuildPhase: string;
    function SectionPBXSourcesBuildPhase: string;
  public
    { Flattened list of *all* files within a project. Owns items. }
    Files: TXCodeProjectFileList;
    Frameworks: TXCodeProjectFrameworkList;
    constructor Create;
    destructor Destroy; override;
    procedure AddTopLevelDir(const Path, Name: string);
    { Generated contents to be inserted into the pbxproj file. }
    function PBXContents: string;
  end;

implementation

uses StrUtils,
  CastleStringUtils, CastleUtils, CastleLog;

var
  XCodeUuidNext: Int64;

{ UUID in XCode project: 12 bytes for unique id.
  We use 6 bytes for random number, 6 bytes for the next sequential number
  (thus guaranteeing that within a single run, the numbers will be different,
  no matter about the random quality). }
function GenXCodeUuid: string;
var
  RandomPart: Int64;
begin
  RandomPart := Random(Int64(1) shl (6 * 8));
  Inc(XCodeUuidNext);
  Result :=
    IntToHex(RandomPart, 6 * 2) +
    IntToHex(XCodeUuidNext, 6 * 2);
end;

{ TXCodeProjectFramework ---------------------------------------------------------- }

constructor TXCodeProjectFramework.Create(const AName: string);
begin
  inherited Create;
  FileUuid := GenXCodeUuid;
  BuildUuid := GenXCodeUuid;
  Name := AName;
end;

{ TXCodeProjectFile ---------------------------------------------------------- }

constructor TXCodeProjectFile.Create;
begin
  inherited Create;
  Children := TXCodeProjectFileList.Create(false);
  FileUuid := GenXCodeUuid;
  BuildUuid := GenXCodeUuid;
end;

constructor TXCodeProjectFile.Create(const FileInfo: TFileInfo);
begin
  Create;
  Name := FileInfo.Name;
  Directory := FileInfo.Directory;
end;

destructor TXCodeProjectFile.Destroy;
begin
  FreeAndNil(Children);
  inherited;
end;

function TXCodeProjectFile.FileType: string;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(Name));
  if E = '.c' then
    Result := 'sourcecode.c.c'
  else
  if E = '.m' then
    Result := 'sourcecode.c.objc'
  else
  if (E = '.h') or (E = '.pch') then
    Result := 'sourcecode.c.h'
  else
  if E = '.txt' then
    Result := 'text'
  else
  if E = '.plist' then
    Result := 'text.plist.xml'
  else
  if E = '.entitlements' then
    Result := 'text.plist.entitlements'
  else
  begin
    WarningWrite('Unrecognized file extension in XCode project: "%s" on file "%s". Assuming a text file.',
      [E, Name]);
    Result := 'text';
  end;
end;

function TXCodeProjectFile.BuildGroup: string;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(Name));
  if (E = '.c') or (E = '.m') then
    Result := 'Sources'
  else
  // Uncomment this to copy .txt files to the final application.
  // if E = '.txt' then
  //   Result := 'Resources'
  // else
    Result := '';
end;

procedure TXCodeProjectFile.AddChildFile(
  const FileInfo: TFileInfo; var StopSearch: boolean);
var
  F: TXCodeProjectFile;
begin
  // These are deliberately treated exceptionally by the generation code
  if SameText(FileInfo.Name, 'en.lproj') or
     SameText(FileInfo.Name, 'Images.xcassets') then
    Exit;

  if IsWild(FileInfo.Name, '*~', true) or
     IsWild(FileInfo.Name, '*.a', true) or
     SameText(FileInfo.Name, 'data') then
  begin
    WritelnWarning('File name "' + FileInfo.Name + '" should not be present in the iOS project template directory, ignoring');
    Exit;
  end;

  if SpecialDirName(FileInfo.Name) then Exit;

  F := TXCodeProjectFile.Create(FileInfo);
  Children.Add(F);
  Project.Files.Add(F);
  F.Project := Project;

  { recursively scan children }
  if FileInfo.Directory then
    FindFiles(FileInfo.AbsoluteName, '*', true, @F.AddChildFile, []);
end;

{ TXCodeProject -------------------------------------------------------------- }

constructor TXCodeProject.Create;
begin
  inherited;
  Files := TXCodeProjectFileList.Create(true);
  Frameworks := TXCodeProjectFrameworkList.Create(true);
end;

destructor TXCodeProject.Destroy;
begin
  FreeAndNil(Files);
  FreeAndNil(Frameworks);
  inherited;
end;

procedure TXCodeProject.AddTopLevelDir(const Path, Name: string);
begin
  TopLevelDir := TXCodeProjectFile.Create;
  TopLevelDir.Name := Name;
  TopLevelDir.Directory := true;
  TopLevelDir.Project := Self;
  Files.Add(TopLevelDir);

  { recursively scan children }
  FindFiles(InclPathDelim(Path) + Name, '*', true, @TopLevelDir.AddChildFile, []);
end;

function TXCodeProject.SectionPBXFileReference: string;
var
  F: TXCodeProjectFile;
  Fr: TXCodeProjectFramework;
begin
  Result := '/* Begin PBXFileReference section */' + NL;

  for F in Files do
    if not F.Directory then
    begin
      Result := Result + Format(
        #9#9'%s /* %s */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = %s; path = "%s"; sourceTree = "<group>"; };' + NL,
        [F.FileUuid, F.Name, F.FileType, F.Name]);
    end;

  for Fr in Frameworks do
    Result := Result + Format(
      #9#9'%s /* %s.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = %s.framework; path = System/Library/Frameworks/%s.framework; sourceTree = SDKROOT; };' + NL,
      [Fr.FileUuid, Fr.Name, Fr.Name, Fr.Name]);

  Result := Result +
    { specials }
    #9#9'4D629DF41916B0EB0082689B /* ${CAPTION}.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "${CAPTION}.app"; sourceTree = BUILT_PRODUCTS_DIR; };' + NL +
    #9#9'4D629E011916B0EB0082689B /* en */ = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = en; path = en.lproj/InfoPlist.strings; sourceTree = "<group>"; };' + NL +
    #9#9'4D629E091916B0EB0082689B /* Images.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Images.xcassets; sourceTree = "<group>"; };' + NL +
    #9#9'4D629E2A1916B7A40082689B /* ${IOS_LIBRARY_BASE_NAME} */ = {isa = PBXFileReference; lastKnownFileType = archive.ar; path = ${IOS_LIBRARY_BASE_NAME}; sourceTree = "<group>"; };' + NL +
    #9#9'4D90CC2119197A82004E90CC /* data */ = {isa = PBXFileReference; lastKnownFileType = folder; name = data; path = ${NAME}/data; sourceTree = "<group>"; };' + NL +

    '/* End PBXFileReference section */' + NL + NL;
end;

function TXCodeProject.SectionPBXBuildFile: string;
var
  F: TXCodeProjectFile;
  Fr: TXCodeProjectFramework;
  BuildGroup: string;
begin
  Result := '/* Begin PBXBuildFile section */' + NL;

  for F in Files do
    if not F.Directory then
    begin
      BuildGroup := F.BuildGroup;
      if BuildGroup <> '' then
        Result := Result + Format(
          #9#9'%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };' + NL,
          [F.BuildUuid, F.Name, BuildGroup, F.FileUuid, F.Name]);
    end;

  for Fr in Frameworks do
    Result := Result + Format(
      #9#9'%s /* %s.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = %s /* %s.framework */; };' + NL,
      [Fr.BuildUuid, Fr.Name, Fr.FileUuid, Fr.Name]);

  Result := Result +
    { specials }
    #9#9'4D629E021916B0EB0082689B /* InfoPlist.strings in Resources */ = {isa = PBXBuildFile; fileRef = 4D629E001916B0EB0082689B /* InfoPlist.strings */; };' + NL +
    #9#9'4D629E0A1916B0EB0082689B /* Images.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = 4D629E091916B0EB0082689B /* Images.xcassets */; };' + NL +
    #9#9'4D629E2B1916B7A40082689B /* ${IOS_LIBRARY_BASE_NAME} in Frameworks */ = {isa = PBXBuildFile; fileRef = 4D629E2A1916B7A40082689B /* ${IOS_LIBRARY_BASE_NAME} */; };' + NL +
    #9#9'4D90CC2219197A82004E90CC /* data in Resources */ = {isa = PBXBuildFile; fileRef = 4D90CC2119197A82004E90CC /* data */; };' + NL +

    '/* End PBXBuildFile section */' + NL + NL;
end;

function TXCodeProject.SectionPBXGroup: string;
var
  F, Child: TXCodeProjectFile;
  Fr: TXCodeProjectFramework;
  SupportingFiles: TXCodeProjectFileList;
  E: string;
begin
  Result := '/* Begin PBXGroup section */' + NL;
  SupportingFiles := TXCodeProjectFileList.Create(false);

  { each directory is a group }
  for F in Files do
    if F.Directory then
    begin
      Result := Result + Format(
        #9#9'%s /* %s */ = {' + NL +
        #9#9#9'isa = PBXGroup;' + NL +
        #9#9#9'children = (' + NL,
        [F.FileUuid, F.Name]);

      for Child in F.Children do
      begin
        { some files should be placed in "Supporting Files" instead }
        E := LowerCase(ExtractFileExt(Child.Name));
        if (E = '.plist') or (E = '.pch') then
          SupportingFiles.Add(Child)
        else
        begin
          Result := Result + Format(
            #9#9#9#9'%s /* %s */,' + NL,
            [Child.FileUuid, Child.Name]);
        end;
      end;

      if F = TopLevelDir then
      begin
        Result := Result +
          #9#9#9#9'4D629E091916B0EB0082689B /* Images.xcassets */,' + NL +
          #9#9#9#9'4D629DFE1916B0EB0082689B /* Supporting Files */,' + NL;
      end;

      Result := Result + Format(
        #9#9#9');' + NL +
        #9#9#9'path = "%s";' + NL +
        #9#9#9'sourceTree = "<group>";' + NL +
        #9#9'};' + NL,
        [F.Name]);
    end;

  { Frameworks group }
  Result := Result +
    #9#9'4D629DF61916B0EB0082689B /* Frameworks */ = {' + NL +
    #9#9#9'isa = PBXGroup;' + NL +
    #9#9#9'children = (' + NL +
    #9#9#9#9'4D629E2A1916B7A40082689B /* ${IOS_LIBRARY_BASE_NAME} */,' + NL;
  for Fr in Frameworks do
    Result := Result + Format(
      #9#9#9#9'%s /* %s.framework */,' + NL,
      [Fr.FileUuid, Fr.Name]);
  Result := Result +
    #9#9#9');' + NL +
    #9#9#9'name = Frameworks;' + NL +
    #9#9#9'sourceTree = "<group>";' + NL +
    #9#9'};' + NL;

  { special main (nameless) group }
  Result := Result +
    #9#9'4D629DEB1916B0EA0082689B = {' + NL +
    #9#9#9'isa = PBXGroup;' + NL +
    #9#9#9'children = (' + NL +
    #9#9#9#9 + TopLevelDir.FileUuid + ' /* ${NAME} */,' + NL +
    #9#9#9#9'4D90CC2119197A82004E90CC /* data */,' + NL +
    #9#9#9#9'4D629DF61916B0EB0082689B /* Frameworks */,' + NL +
    #9#9#9#9'4D629DF51916B0EB0082689B /* Products */,' + NL +
    #9#9#9');' + NL +
    #9#9#9'sourceTree = "<group>";' + NL +
    #9#9'};' + NL;

  { Products group }
  Result := Result +
    #9#9'4D629DF51916B0EB0082689B /* Products */ = {' + NL +
    #9#9#9'isa = PBXGroup;' + NL +
    #9#9#9'children = (' + NL +
    #9#9#9#9'4D629DF41916B0EB0082689B /* ${CAPTION}.app */,' + NL +
    #9#9#9');' + NL +
    #9#9#9'name = Products;' + NL +
    #9#9#9'sourceTree = "<group>";' + NL +
    #9#9'};' + NL;

  { Supporting Files group }
  Result := Result +
    #9#9'4D629DFE1916B0EB0082689B /* Supporting Files */ = {' + NL +
    #9#9#9'isa = PBXGroup;' + NL +
    #9#9#9'children = (' + NL +
    #9#9#9#9'4D629E001916B0EB0082689B /* InfoPlist.strings */,' + NL;
  for Child in SupportingFiles do
    Result := Result + Format(
      #9#9#9#9'%s /* %s */,' + NL,
      [Child.FileUuid, Child.Name]);
  Result := Result +
    #9#9#9');' + NL +
    #9#9#9'name = "Supporting Files";' + NL +
    #9#9#9'sourceTree = "<group>";' + NL +
    #9#9'};' + NL;

  Result := Result +
    '/* End PBXGroup section */' + NL + NL;

  FreeAndNil(SupportingFiles);
end;

function TXCodeProject.SectionPBXFrameworksBuildPhase: string;
var
  Fr: TXCodeProjectFramework;
begin
  Result := '/* Begin PBXFrameworksBuildPhase section */' + NL +
    #9#9'4D629DF11916B0EB0082689B /* Frameworks */ = {' + NL +
    #9#9#9'isa = PBXFrameworksBuildPhase;' + NL +
    #9#9#9'buildActionMask = 2147483647;' + NL +
    #9#9#9'files = (' + NL +
    #9#9#9#9'4D629E2B1916B7A40082689B /* ${IOS_LIBRARY_BASE_NAME} in Frameworks */,' + NL;

  for Fr in Frameworks do
    Result := Result + Format(
      #9#9#9#9'%s /* %s.framework in Frameworks */,' + NL,
      [Fr.BuildUuid, Fr.Name]);

  Result := Result +
    #9#9#9');' + NL +
    #9#9#9'runOnlyForDeploymentPostprocessing = 0;' + NL +
    #9#9'};' + NL +
    '/* End PBXFrameworksBuildPhase section */' + NL + NL;
end;

function TXCodeProject.SectionPBXResourcesBuildPhase: string;
var
  F: TXCodeProjectFile;
begin
  Result := '/* Begin PBXResourcesBuildPhase section */' + NL +
    #9#9'4D629DF21916B0EB0082689B /* Resources */ = {' + NL +
    #9#9#9'isa = PBXResourcesBuildPhase;' + NL +
    #9#9#9'buildActionMask = 2147483647;' + NL +
    #9#9#9'files = (' + NL +
    #9#9#9#9'4D629E021916B0EB0082689B /* InfoPlist.strings in Resources */,' + NL +
    #9#9#9#9'4D90CC2219197A82004E90CC /* data in Resources */,' + NL +
    #9#9#9#9'4D629E0A1916B0EB0082689B /* Images.xcassets in Resources */,' + NL;

  { The loop below does nothing for now, as the BuildGroup is never 'Resources'
    now for any file. Maybe it will be useful in the future. }
  for F in Files do
    if F.BuildGroup = 'Resources' then
      Result := Result + Format(
        #9#9#9#9'%s /* %s in %s */,' + NL,
        [F.BuildUuid, F.Name, F.BuildGroup]);

  Result := Result +
    #9#9#9');' + NL +
    #9#9#9'runOnlyForDeploymentPostprocessing = 0;' + NL +
    #9#9'};' + NL +
    '/* End PBXResourcesBuildPhase section */' + NL + NL;
end;

function TXCodeProject.SectionPBXSourcesBuildPhase: string;
var
  F: TXCodeProjectFile;
begin
  Result := '/* Begin PBXSourcesBuildPhase section */' + NL +
    #9#9'4D629DF01916B0EB0082689B /* Sources */ = {' + NL +
    #9#9#9'isa = PBXSourcesBuildPhase;' + NL +
    #9#9#9'buildActionMask = 2147483647;' + NL +
    #9#9#9'files = (' + NL;

  for F in Files do
    if F.BuildGroup = 'Sources' then
      Result := Result + Format(
        #9#9#9#9'%s /* %s in %s */,' + NL,
        [F.BuildUuid, F.Name, F.BuildGroup]);

  Result := Result +
    #9#9#9');' + NL +
    #9#9#9'runOnlyForDeploymentPostprocessing = 0;' + NL +
    #9#9'};' + NL +
    '/* End PBXSourcesBuildPhase section */' + NL + NL;
end;

function TXCodeProject.PBXContents: string;
begin
  Result :=
    SectionPBXFileReference +
    SectionPBXBuildFile +
    SectionPBXGroup +
    SectionPBXFrameworksBuildPhase +
    SectionPBXResourcesBuildPhase +
    SectionPBXSourcesBuildPhase;
end;

end.

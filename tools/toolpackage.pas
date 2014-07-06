{
  Copyright 2014-2014 Michalis Kamburelis and FPC team.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Packaging data in archives. }
unit ToolPackage;

interface

type
  TPackageType = (ptZip, ptTarGz);

  TPackageDirectory = class
  private
    TemporaryDir: string;
    FPath: string;
    FTopDirectoryName: string;

    { Absolute path (ends with path delimiter) under which you should
      store your files. They will end up being packaged,
      under TopDirectoryName. }
    property Path: string read FPath;
    property TopDirectoryName: string read FTopDirectoryName;
  public
    constructor Create(const ATopDirectoryName: string);
    destructor Destroy; override;

    { Create final archive. It will be placed within ProjectPath.
      PackageName should contain only the base name, without extension. }
    procedure Make(const ProjectPath: string; const PackageFileName: string;
      const PackageType: TPackageType);

    { Add file to the package. SourceFileName must be an absolute filename,
      DestinationFileName must be relative within package. }
    procedure Add(const SourceFileName, DestinationFileName: string);

    { Set the Unix executable bit on given file. Name is relative to package path,
      just like DestinationFileName for @link(Add). }
    procedure MakeExecutable(const Name: string);
  end;

implementation

uses SysUtils, Process, {$ifdef UNIX} BaseUnix, {$endif}
  CastleUtils, CastleFilesUtils,
  ToolUtils;

constructor TPackageDirectory.Create(const ATopDirectoryName: string);
begin
  inherited Create;

  FTopDirectoryName := ATopDirectoryName;

  TemporaryDir := InclPathDelim(GetTempDir(false)) +
    ApplicationName + IntToStr(Random(1000000));
  CheckForceDirectories(TemporaryDir);
  if Verbose then
    Writeln('Created temporary dir for package: ' + TemporaryDir);

  FPath := InclPathDelim(TemporaryDir) + TopDirectoryName;
  CheckForceDirectories(FPath);
  FPath += PathDelim;
end;

destructor TPackageDirectory.Destroy;
begin
  RemoveNonEmptyDir(TemporaryDir);
  inherited;
end;

procedure TPackageDirectory.Make(const ProjectPath: string;
  const PackageFileName: string; const PackageType: TPackageType);
var
  FullPackageFileName, ProcessOutput: string;
  ProcessExitStatus: Integer;
begin
  case PackageType of
    ptZip:
      RunCommandIndir(TemporaryDir, 'zip',
        ['-q', '-r', PackageFileName, TopDirectoryName],
        ProcessOutput, ProcessExitStatus);
    ptTarGz:
      RunCommandIndir(TemporaryDir, 'tar',
        ['czf', PackageFileName, TopDirectoryName],
        ProcessOutput, ProcessExitStatus);
    else raise EInternalError.Create('TPackageDirectory.Make PackageType?');
  end;

  if Verbose then
  begin
    Writeln('Executed package process, output:');
    Writeln(ProcessOutput);
  end;

  if ProcessExitStatus <> 0 then
    raise Exception.CreateFmt('Package process exited with error, status %d', [ProcessExitStatus]);

  FullPackageFileName := ProjectPath + PackageFileName;
  DeleteFile(FullPackageFileName);
  CheckRenameFile(InclPathDelim(TemporaryDir) + PackageFileName, FullPackageFileName);
  Writeln('Created package ' + PackageFileName + ', size: ',
    (FileSize(FullPackageFileName) / (1024 * 1024)):0:2, ' MB');
end;

procedure TPackageDirectory.Add(const SourceFileName, DestinationFileName: string);
begin
  SmartCopyFile(SourceFileName, Path + DestinationFileName);
  if Verbose then
    Writeln('Package file: ' + DestinationFileName);
end;

procedure TPackageDirectory.MakeExecutable(const Name: string);
begin
  {$ifdef UNIX}
  FpChmod(Path + Name,
    S_IRUSR or S_IWUSR or S_IXUSR or
    S_IRGRP or            S_IXGRP or
    S_IROTH or            S_IXOTH);
  {$else}
  OnWarning(wtMajor, 'Package', 'Packaging for a platform where UNIX permissions matter, but we cannot set "chmod" on this platform. This usually means that you package for Unix from Windows, and means that "executable" bit inside binary in tar.gz archive may not be set --- archive');
  {$endif}
end;

end.
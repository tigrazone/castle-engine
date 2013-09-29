{
  Copyright 2013-2013 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

unit TestVideos;

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry, CastleVideos;

type
  TTestVideos = class(TTestCase)
  published
    procedure TestLoad;
  end;

implementation

uses CastleFilesUtils;

procedure TTestVideos.TestLoad;
var
  Video: TVideo;
begin
  Video := TVideo.Create;
  try
    Video.LoadFromFile(ApplicationData('videos/video1_@counter(4).png'));
    Assert(Video.Count = 3);
    Video.LoadFromFile(ApplicationData('videos/video2_@counter(4).png'));
    Assert(Video.Count = 3);
    Video.LoadFromFile(ApplicationData('videos/video_single.png'));
    Assert(Video.Count = 1);

    try
      Video.LoadFromFile(ApplicationData('videos/video_not_existing.png'));
      Assert(false, 'Should fail');
    except
      on E: Exception do
      begin
//        Writeln(E.Message);
      end;
    end;

    try
      Video.LoadFromFile(ApplicationData('videos/video_not_existing@counter(1).png'));
      Assert(false, 'Should fail');
    except
      on E: Exception do
      begin
//        Writeln(E.Message);
        Assert(Pos('cannot be loaded', E.Message) <> 0);
      end;
    end;
  finally FreeAndNil(Video) end;
end;

initialization
 RegisterTest(TTestVideos);
end.
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

{ OggVorbis decoder. }
unit CastleInternalVorbisDecoder;

{$I castleconf.inc}

interface

uses SysUtils, Classes, CastleInternalOpenAL;

type
  EVorbisLoadError = class(Exception);
  EVorbisMissingLibraryError = class(EVorbisLoadError);
  EVorbisFileError = class(EVorbisLoadError);

{ OggVorbis decoder using LibVorbisFile or Tremolo libraries
  and working on ObjectPascal TStream objects.

  This checks VorbisFileInitialized at the beginning, so you don't have to
  worry about it.

  Note: this only uses some constants from OpenAL unit. It doesn't
  actually require OpenAL library to be available and initialized.

  @raises(EStreamError If Stream cannot be read (e.g. ended prematurely).)
  @raises(EVorbisLoadError If decoding OggVorbis stream failed,
    this may also happen if the vorbisfile / tremolo library is not available.) }
function VorbisDecode(Stream: TStream; out DataFormat: TALuint;
  out Frequency: LongWord): TMemoryStream;

implementation

uses CastleUtils, CastleInternalVorbisFile, CastleinternalvorbisCodec, CTypes;

{ VorbisDecoder_ callbacks code based on Noeska code from
  [http://www.noeska.com/doal/tutorials.aspx].
  Heavily modified for CGE (e.g. to allow exceptions raising in case of
  stream errors (instead of silencing these exceptions), to check (ReadCount mod
  Size) in read_func and whence in seek_func, close does nothing). }

function VorbisDecoder_read_func(ptr: Pointer;
  Size: TSizeT; nmemb: TSizeT; DataSource: Pointer): TSizeT; cdecl;
{ Returns amount of items completely read successfully, returns indeterminate
  value on error. The value of a partially read item cannot be determined. Does
  not lead to valid feof or ferror responses, because they are not possible to
  supply to VorbisFile }
var
  ReadCount: Int64;
begin
  if (size = 0) or (nmemb = 0) then
  begin
    Result := 0;
    Exit;
  end;

  ReadCount := TStream(DataSource).Read(ptr^, Size * nmemb);
  Assert(ReadCount mod Size = 0);
  Result := ReadCount div Size;
end;

function VorbisDecoder_seek_func(DataSource: Pointer;
  offset: Int64; whence: CInt): CInt; cdecl;
const
  SEEK_SET = 0;
  SEEK_CUR = 1;
  SEEK_END = 2;
begin
  try
    case whence of
      SEEK_CUR: TStream(DataSource).Seek(offset, soFromCurrent);
      SEEK_END: TStream(DataSource).Seek(offset, soFromEnd);
      SEEK_SET: TStream(DataSource).Seek(offset, soFromBeginning);
      else raise EInternalError.CreateFmt('Invalid VorbisDecoder_seek_func ' +
        'whence param: %d', [whence]);
    end;
    Result := 0;
  except
    { If the Stream is unseekable, vorbisfile allows us to return here -1. }
    Result := -1;
  end;
end;

function VorbisDecoder_close_func(DataSource: Pointer): CInt;
  cdecl;
begin
  Result := 0;
end;

function VorbisDecoder_tell_func(DataSource: Pointer): CLong;
  cdecl;
begin
  Result := TStream(DataSource).Position;
end;

{ Simple encoding of OggVorbis is implemented based on
  [http://www.gamedev.net/reference/articles/article2031.asp].
  I reworked it a lot (I have to use callbacks to handle Pascal streams,
  I check for errors). See [http://xiph.org/vorbis/doc/vorbisfile/index.html]
  for vorbisfile overview. }

function VorbisDecode(Stream: TStream; out DataFormat: TALuint;
  out Frequency: LongWord): TMemoryStream;

  procedure CheckVorbisFile(Err: CInt; const Event: string);
  var
    ErrDescription: string;
  begin
    { Errors list and ErrDescription values based on
      [http://xiph.org/vorbis/doc/vorbisfile/return.html] }
    case Err of
      OV_FALSE: ErrDescription := 'No data available';
      OV_HOLE: ErrDescription := 'Vorbisfile encountered missing or corrupt data in the bitstream'; {. Recovery is normally automatic and this return code is for informational purposes only. }
      OV_EREAD: ErrDescription := 'Read error while fetching compressed data for decode';
      OV_EFAULT: ErrDescription := 'Internal inconsistency in decode state'; {. Continuing is likely not possible. }
      OV_EIMPL: ErrDescription := 'Feature not implemented';
      OV_EINVAL: ErrDescription := 'Either an invalid argument, or incompletely initialized argument passed to libvorbisfile call';
      OV_ENOTVORBIS: ErrDescription := 'The given file/data was not recognized as Ogg Vorbis data';
      OV_EBADHEADER: ErrDescription := 'The file/data is apparently an Ogg Vorbis stream, but contains a corrupted or undecipherable header';
      OV_EVERSION: ErrDescription := 'The bitstream format revision of the given stream is not supported';
      OV_EBADLINK: ErrDescription := 'The given link exists in the Vorbis data stream, but is not decipherable due to garbacge or corruption';
      OV_ENOSEEK: ErrDescription := 'The given stream is not seekable';
      else ErrDescription := '(unknown vorbisfile error code)';
    end;

    if Err <> 0 then
      raise EVorbisFileError.CreateFmt('VorbisFile error %d at "%s": %s',
        [Err, Event, ErrDescription]);
  end;

const
  { Noone uses ogg vorbis with small files, so it's sensible to make
    this buffer at least 1 MB. Above this, increasing BufSize doesn't
    seem to make loading OggVorbis faster. }
  BufSize = 1000 * 1000;

var
  OggFile: TOggVorbis_File;
  OggInfo: Pvorbis_info;
  Callbacks: Tov_callbacks;
  ReadCount: CLong;
  Buffer: Pointer;
  BitStream: CInt;
begin
  if not VorbisFileInitialized then
    raise EVorbisMissingLibraryError.Create('Library to decode OggVorbis (LibVorbisFile on desktops, Tremolo on mobile) is not available');

  Result := TMemoryStream.Create;
  try
    Callbacks.read_func := @VorbisDecoder_read_func;
    Callbacks.seek_func := @VorbisDecoder_seek_func;
    Callbacks.close_func := @VorbisDecoder_close_func;
    Callbacks.tell_func := @VorbisDecoder_tell_func;
    CheckVorbisFile(ov_open_callbacks(Stream, @OggFile, nil, 0, Callbacks),
      'ov_open_callbacks');

    OggInfo := ov_info(@OggFile, -1);

    if OggInfo^.channels = 1 then
      DataFormat := AL_FORMAT_MONO16
    else
      DataFormat := AL_FORMAT_STEREO16;

    Frequency := OggInfo^.rate;

    Buffer := GetMem(BufSize);
    try

      repeat
        ReadCount := ov_read(@OggFile, Buffer^, BufSize,
          { OpenAL always wants little endian ? } 0,
          { Always give us 16 bits } 2, 1, @BitStream);

        if ReadCount < 0 then
          CheckVorbisFile(ReadCount, 'ov_read');

        Result.WriteBuffer(Buffer^, ReadCount);
      until ReadCount <= 0;

    finally FreeMemNiling(Buffer) end;

    ov_clear(@OggFile);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

end.

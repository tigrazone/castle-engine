{
  Copyright 2013-2017 Jan Adamec, Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in the "Castle Game Engine" distribution,
  for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Library to run the game on iOS. }
library ${NAME_PASCAL};

uses Math, CastleWindow, CastleMessaging, ${GAME_UNITS};

{ Qualify identifiers by unit names below,
  to prevent GAME_UNITS from changing the meaning of code below. }

exports
  CastleWindow.CGEApp_Open,
  CastleWindow.CGEApp_Close,
  CastleWindow.CGEApp_Render,
  CastleWindow.CGEApp_Resize,
  CastleWindow.CGEApp_SetLibraryCallbackProc,
  CastleWindow.CGEApp_Update,
  CastleWindow.CGEApp_MouseDown,
  CastleWindow.CGEApp_Motion,
  CastleWindow.CGEApp_MouseUp,
  CastleWindow.CGEApp_KeyDown,
  CastleWindow.CGEApp_KeyUp,
  CastleWindow.CGEApp_SetDpi,
  CastleWindow.CGEApp_HandleOpenUrl,
  CastleMessaging.CGEApp_SetReceiveMessageFromPascalCallback,
  CastleMessaging.CGEApp_SendMessageToPascal;

begin
  Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
end.

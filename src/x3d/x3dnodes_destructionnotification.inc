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

  TNodeDestructionNotification = procedure (Node: TX3DNode) of object;

  TNodeDestructionNotificationList = class(specialize TList<TNodeDestructionNotification>)
  public
    { Call all functions. }
    procedure ExecuteAll(Node: TX3DNode);
  end;

{$endif read_interface}

{$ifdef read_implementation}

{ TNodeDestructionNotificationList ------------------------------------------- }

procedure TNodeDestructionNotificationList.ExecuteAll(Node: TX3DNode);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I](Node);
end;

{$endif read_implementation}

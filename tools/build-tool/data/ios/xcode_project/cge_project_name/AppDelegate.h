/*
  Copyright 2013-2017 Jan Adamec, Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in the "Castle Game Engine" distribution,
  for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
*/

#import <UIKit/UIKit.h>
#include "castleiosappglue.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    /* Services (integrations with 3rd party services).
       Array of ServiceAbstract instances. */
    NSMutableArray* services;
}
- (void)messageReceived:(const char *)message;

@property (strong, nonatomic) UIWindow *window;

@end

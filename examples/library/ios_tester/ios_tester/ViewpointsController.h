/*
  Copyright 2013-2017 Jan Adamec, Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
*/

#import <Foundation/Foundation.h>

@protocol ViewpointCtlDelegate
- (void)viewpointDidChange:(int)nNewViewpoint;
@end

@interface ViewpointsController : UITableViewController

@property (nonatomic, weak) id<ViewpointCtlDelegate> delegate;
@property (nonatomic, strong) NSMutableArray* arrayViewpoints;
@property (nonatomic, assign) NSInteger selectedViewpoint;

@end

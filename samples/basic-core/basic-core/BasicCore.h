//
//  BasicCore.h
//  basic-core
//
//  Copyright © 2018 Graham Miln. All rights reserved.
//

@import Cocoa;

/** BasicCore is an example application for UpdateCore. */
@interface BasicCore : NSObject <NSApplicationDelegate>

- (IBAction)discover:(id)aSender;
- (IBAction)download:(id)aSender;
- (IBAction)install:(id)aSender;
- (IBAction)installSelectedPackage:(id)aSender;

- (IBAction)cancel:(id)aSender;
- (IBAction)reset:(id)aSender;



@end


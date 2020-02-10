//
//  UCUpdateInstaller.h
//  UpdateCore
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//

@import Foundation;
#import "UCUpdate.h"

NS_ASSUME_NONNULL_BEGIN

@interface UCUpdateInstaller : NSObject
@property(strong,readonly) UCUpdate* update;

+ (instancetype)installerWithUpdate:(UCUpdate*)inUpdate queue:(NSOperationQueue* __nullable)inQueue;
- (instancetype)initWithUpdate:(UCUpdate*)inUpdate queue:(NSOperationQueue* __nullable)inQueue NS_DESIGNATED_INITIALIZER;

//- (void)downloadWithCompletionHandler:(void(^ __nullable)(NSError* __nullable))handler;

//- (void)installWithCompletionHandler:(void(^ __nullable)(NSError* __nullable))handler;

// Use +installerWithUpdate:… or -initWithUpdate:…
+ (instancetype)new __attribute__((unavailable("new not available")));
- (instancetype)init __attribute__((unavailable("init not available")));

@end

NS_ASSUME_NONNULL_END


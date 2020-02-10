//
//  UCUpdateInstall.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

// KVO
extern NSString* UCUpdateInstallKeyLocalizedProgress;

@interface UCUpdateInstall : NSObject <NSProgressReporting>
@property(strong,readonly) NSString* localizedProgress; /**< Install specific progress. */
@property(assign,readonly) BOOL isFinished; /**< Has the install finished. */
@property(strong,readonly) NSError* error; /**< Error that blocked the installation. */

/** Request authority to install software and, if granted, set up the privileged helper tool. If authority has previously been granted this will do nothing. */
+ (void)requestAuthorityWithQueue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSError* __nullable))inHandler;

+ (instancetype)installWithFileURL:(NSURL*)inFileURL queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSError* __nullable))inHandler;
- (instancetype)initWithFileURL:(NSURL*)inFileURL queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSError* __nullable))inHandler  NS_DESIGNATED_INITIALIZER;

+ (instancetype)new __attribute__((unavailable("new not available")));
- (instancetype)init __attribute__((unavailable("init not available")));

@end

NS_ASSUME_NONNULL_END

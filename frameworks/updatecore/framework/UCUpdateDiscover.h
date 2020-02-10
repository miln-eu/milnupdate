//
//  UCUpdateDiscover.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;
#import "UCUpdate.h"

NS_ASSUME_NONNULL_BEGIN

/** UCUpdateDiscover fetches and parses a discovery URL for an update. */
@interface UCUpdateDiscover : NSObject <NSProgressReporting>
@property(class,readonly) NSString* systemVersion; /**< Operating system version. */
@property(assign,readonly) BOOL isFinished; /**< Has the update check finished. */
@property(strong,readonly) NSError* error; /**< Error that blocked the update process. */
@property(strong,readonly) UCUpdate* available; /**< Update available for installation. */

/** Download and parse an update feed. */
+ (instancetype)discoverWithURL:(NSURL*)inDiscoveryURL revision:(NSString*)inRevision systemVersion:(NSString*)inSystemVersion queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(UCUpdate* __nullable,NSError* __nullable))handler;
- (instancetype)initWithURL:(NSURL*)inDiscoveryURL revision:(NSString*)inRevision systemVersion:(NSString*)inSystemVersion queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(UCUpdate* __nullable,NSError* __nullable))handler NS_DESIGNATED_INITIALIZER;

+ (instancetype)new __attribute__((unavailable("new not available; use discoverWithURL:")));
- (instancetype)init __attribute__((unavailable("init not available; use initWithURL:")));

@end

NS_ASSUME_NONNULL_END

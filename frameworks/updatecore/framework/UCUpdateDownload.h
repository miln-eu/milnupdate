//
//  UCUpdateDownload.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;
@import Security;

NS_ASSUME_NONNULL_BEGIN

// KVO
extern NSString* UCUpdateDownloadKeyLocalizedProgress;

@interface UCUpdateDownload : NSObject <NSProgressReporting>
@property(assign,readonly) BOOL isFinished; /**< Has the download finished. */
@property(strong,readonly) NSError* error; /**< Error that blocked the download. */
@property(strong,readonly) NSString* localizedProgress; /**< Download specific progress. */
@property(strong,readonly) NSURL* fileURL; /**< Local file URL to downloaded file. Removed when instance is released. */
@property(strong,readonly) NSString* commonName; /**< Common name of leaf certificate used to sign package. Originator in `spctl` terminology. */

/** Download and verify a file. Verification requires the downloaded file is accepted by `spctl` for installation. */
+ (instancetype)downloadWithRequest:(NSURLRequest*)inRequest queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSURL* __nullable,NSString* __nullable, NSError* __nullable))inHandler;
- (instancetype)initWithRequest:(NSURLRequest*)inRequest queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSURL* __nullable,NSString* __nullable, NSError* __nullable))inHandler NS_DESIGNATED_INITIALIZER;

/** Cancel download. */
- (void)cancel;

/** Clear cached downloads. */
+ (void)clearCache;

// Use +downloadWithRequest:… or -initWithRequest:…
+ (instancetype)new __attribute__((unavailable("new not available")));
- (instancetype)init __attribute__((unavailable("init not available")));

@end

NS_ASSUME_NONNULL_END

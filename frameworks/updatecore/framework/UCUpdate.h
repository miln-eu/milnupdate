//
//  UCUpdate.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface UCUpdate : NSObject
@property(strong,readonly) NSString* revision;
@property(strong,readonly) NSString* minimumSystemVersion;
@property(strong,readonly) NSURL* downloadURL;

+ (instancetype)updateWithVersion:(NSString*)aVersion minimumSystem:(NSString*)aMinimumSystem downloadURL:(NSURL*)aURL;

// Use +updateWithVersion:…
+ (instancetype)new __attribute__((unavailable("new not available")));
- (instancetype)init __attribute__((unavailable("init not available")));

@end

NS_ASSUME_NONNULL_END

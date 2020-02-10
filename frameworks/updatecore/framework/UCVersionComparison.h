//
//  UCVersionComparison.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@protocol UCVersionComparisonProtocol
- (NSComparisonResult)compareVersion:(NSString*)inLHS toVersion:(NSString*)inRHS;
@end

@interface UCVersionComparison : NSObject <UCVersionComparisonProtocol>
@property(assign) BOOL allowUnstable; /**< Allow unstable (1.1a2) equal standing as stable versions (1.0). Versions with alpha characters are deemed unstable. */

- (NSComparisonResult)compareVersion:(NSString*)inLHS toVersion:(NSString*)inRHS;

/** Return YES if inVersion is considered an unstable version number. */
- (BOOL)isUnstableVersion:(NSString*)inVersion;

@end

NS_ASSUME_NONNULL_END

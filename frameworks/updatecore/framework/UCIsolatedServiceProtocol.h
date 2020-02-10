//
//  UCIsolatedServiceProtocol.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

NS_ASSUME_NONNULL_BEGIN

/** UCIsolatedServiceProtocol tracks the progress of current tasks. */
@protocol UCIsolatedServiceProtocol
- (void)serviceDidBeginTaskWithIdentifier:(NSUUID*)anIdentifier;
- (void)serviceDidUpdateTaskWithIdentifier:(NSUUID*)anIdentifier completing:(NSInteger)inCompletedUnits ofTotalUnits:(NSInteger)inTotalUnits;
- (void)serviceDidUpdateTaskWithIdentifier:(NSUUID*)anIdentifier message:(NSString* __nullable)aMessage;
- (void)serviceDidUpdateTaskWithIdentifier:(NSUUID*)anIdentifier detail:(NSString* __nullable)aDetail;
- (void)serviceDidEndTaskWithIdentifier:(NSUUID*)anIdentifier;
@end

// macOS 10.13 adds support for returning NSProgress instances from XPC connections. UpdateCode supports macOS 10.12, so we can not use this ability.

NS_ASSUME_NONNULL_END


//
//  UCAuthorization.h
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

@interface UCAuthorization : NSObject
@property(assign,readonly) AuthorizationRef authorization;

+ (instancetype)authorizationWithRights:(NSArray<NSString*>*)someRights prompt:(NSString* __nullable)inOptionalPrompt error:(NSError* __autoreleasing *)outError;
- (instancetype)initWithRights:(NSArray<NSString*>*)someRights prompt:(NSString* __nullable)inOptionalPrompt error:(NSError* __autoreleasing *)outError NS_DESIGNATED_INITIALIZER;

// Use +authorizationWithRights:…
+ (instancetype)new __attribute__((unavailable("new not available")));
- (instancetype)init __attribute__((unavailable("init not available")));

@end

NS_ASSUME_NONNULL_END

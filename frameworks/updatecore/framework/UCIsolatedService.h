//
//  UCIsolatedService.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

// Predefined XPC services
typedef NSString * UCIsolatedServiceKey NS_EXTENSIBLE_STRING_ENUM;
extern UCIsolatedServiceKey UCIsolatedServiceKeyDownload;
extern UCIsolatedServiceKey UCIsolatedServiceKeyParse;
extern UCIsolatedServiceKey UCIsolatedServiceKeyVerify;
extern UCIsolatedServiceKey UCIsolatedServiceKeyInstall;

@interface UCIsolatedService : NSObject
+ (instancetype)service:(UCIsolatedServiceKey)inServiceKey withProtocol:(Protocol*)inProtocol;
- (id)asyncWithErrorHandler:(void (^)(NSError *error))handler;
- (id)syncWithErrorHandler:(void (^)(NSError *error))handler;

/** Return progress for a service task. */
- (NSProgress*)progressForIdentifier:(NSUUID*)anIdentifier;
@end

NS_ASSUME_NONNULL_END

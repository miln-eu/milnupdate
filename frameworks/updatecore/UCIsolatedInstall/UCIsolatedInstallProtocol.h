//
//  UCIsolatedInstallProtocol.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@protocol UCIsolatedInstallProtocol
- (void)requestAuthorityWithIdentifier:(NSUUID*)anIdentifier reply:(void (^)(NSError* __nullable inError))reply;
- (void)installWithFile:(NSData*)aFileBookmark identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSError* __nullable inError))reply;
@end

NS_ASSUME_NONNULL_END
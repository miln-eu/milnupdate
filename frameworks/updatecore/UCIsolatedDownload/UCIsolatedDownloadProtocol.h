//
//  UCIsolatedDownloadProtocol.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@protocol UCIsolatedDownloadProtocol
- (void)dataWithContentsOfRequest:(NSURLRequest*)aRequest identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSData* __nullable inDownloadedData, NSError* __nullable inError))reply;

/** Download a file. Caller is responsible for removing the returned file. */
- (void)fileWithContentsOfRequest:(NSURLRequest*)aRequest identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSData* __nullable inBookmarkURL, NSString* __nullable inSuggestedFilename, NSError* __nullable inError))reply;

- (void)cancelDownloadWithIdentifier:(NSUUID*)anIdentifier;
@end

NS_ASSUME_NONNULL_END

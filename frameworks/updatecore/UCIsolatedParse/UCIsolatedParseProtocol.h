//
//  UCIsolatedParseProtocol.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

typedef NSString* UCIsolatedParseKey NS_TYPED_EXTENSIBLE_ENUM;

static UCIsolatedParseKey UCIsolatedParseKeyRevision = @"r";
static UCIsolatedParseKey UCIsolatedParseKeyMinimumSystemVersion = @"msv";
static UCIsolatedParseKey UCIsolatedParseKeyDownloadURL = @"url";

typedef NSDictionary<UCIsolatedParseKey,NSString*>* UCIsolatedParseEntry;
typedef NSArray<UCIsolatedParseEntry>* UCIsolatedParseArrayEntries;

@protocol UCIsolatedParseProtocol
- (void)parseData:(NSData*)someData withReply:(void (^)(UCIsolatedParseArrayEntries __nullable someEntries, NSError* __nullable inError))reply;
@end

NS_ASSUME_NONNULL_END

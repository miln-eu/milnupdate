//
//  UCLineReader.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

@interface UCLineReader : NSObject
@property(copy,readonly) void (^readabilityHandler)(NSFileHandle *);
@property(copy) void (^lineHandler)(NSFileHandle *, NSString *);

- (instancetype)initWithFileHandle:(NSFileHandle*)inFileHandle reader:(void (^)(NSFileHandle *, NSString *))inReader;
- (void)readAvailable;
@end

//
//  UCLineReader.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCLineReader.h"

@interface UCLineReader ()
@property(strong) NSFileHandle* fh;
@property(strong) NSMutableString* buffer;
@end

@implementation UCLineReader

- (instancetype)initWithFileHandle:(NSFileHandle*)inFileHandle reader:(void (^)(NSFileHandle *, NSString *))inReader {
	if ((self = [self init])) {
		self.fh = inFileHandle;
		self.buffer = [NSMutableString new];
		inFileHandle.readabilityHandler = ^(NSFileHandle* inFileHandle) {
			NSData* data = inFileHandle.availableData;
			if (data.length > 0) {
				NSString* text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
				[self.buffer appendString:text];
				BOOL done = NO;
				while(!done) {
					NSRange newlineRange = [self.buffer rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet];
					if (newlineRange.location != NSNotFound) {
						NSString* line = [self.buffer substringToIndex:newlineRange.location + newlineRange.length];
						[self.buffer deleteCharactersInRange:NSMakeRange(0,newlineRange.location + newlineRange.length)];
						inReader(inFileHandle, line);
					} else {
						done = YES;
					}
				}
			} else {
				// Zero length data means file closed
				inFileHandle.readabilityHandler = nil;
				if (self.buffer != nil)
				{
					// Pass final buffer to line reader
					inReader(inFileHandle, self.buffer);
					self.buffer = nil;
				}
			}
		};
	}
	return self;
}

- (void)readAvailable {
	if (self.fh.readabilityHandler != nil) {
		self.fh.readabilityHandler(self.fh);
	}
}

@end

//
//  UCUpdate.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCUpdate.h"

@interface UCUpdate ()
@property(strong,readwrite) NSString* revision;
@property(strong,readwrite) NSString* minimumSystemVersion;
@property(strong,readwrite) NSURL* downloadURL;

- (instancetype)initWithRevision:(NSString*)aRevision minimumSystem:(NSString*)aSystemVersion downloadURL:(NSURL*)aURL NS_DESIGNATED_INITIALIZER;
@end

@implementation UCUpdate

+ (instancetype)updateWithVersion:(NSString*)aVersion minimumSystem:(NSString*)aSystemVersion downloadURL:(NSURL*)aURL {
	return [(UCUpdate*)[[self class] alloc] initWithRevision:aVersion minimumSystem:aSystemVersion downloadURL:aURL];
}

- (instancetype)initWithRevision:(NSString*)aRevision minimumSystem:(NSString*)aMinimumSystem downloadURL:(NSURL*)aURL {
	NSParameterAssert(aRevision);
	NSParameterAssert(aMinimumSystem);
	NSParameterAssert(aURL);
	if ((self = [super init])) {
		self.revision = aRevision;
		self.minimumSystemVersion = aMinimumSystem;
		self.downloadURL = aURL;
	}
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@{%@, %@, %@}", super.description, self.revision, self.minimumSystemVersion, self.downloadURL];
}

@end

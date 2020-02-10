//
//  UpdateCore.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UpdateCorePrivate.h"

@implementation UpdateCore

+ (NSOperationQueue*)sharedQueue {
	static NSOperationQueue* shared = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [NSOperationQueue new];
		shared.name = NSStringFromClass(self.class);
		shared.qualityOfService = NSQualityOfServiceUtility;
	});
	return shared;
}

@end

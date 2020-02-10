//
//  UCUpdateInstaller.m
//  UpdateCore
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//

#import "UCUpdateInstaller.h"

@interface UCUpdateInstaller ()
@property(strong,readwrite) UCUpdate* update;
@property(strong) NSOperationQueue* queue;
@end

@implementation UCUpdateInstaller

+ (instancetype)installerWithUpdate:(UCUpdate*)inUpdate queue:(NSOperationQueue*)inQueue {
	return [(UCUpdateInstaller*)[[self class] alloc] initWithUpdate:inUpdate queue:inQueue];
}

- (instancetype)initWithUpdate:(UCUpdate*)inUpdate queue:(NSOperationQueue*)inQueue {
	if ((self = [super init])) {
		self.update = inUpdate;
		self.queue = inQueue;
	}
	return self;
}

@end

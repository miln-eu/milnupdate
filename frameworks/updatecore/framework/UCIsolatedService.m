//
//  UCIsolatedService.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCIsolatedService.h"
#import "UCIsolatedServiceProtocol.h"

// Info.plist keys associated with compile time derived XPC service names
UCIsolatedServiceKey UCIsolatedServiceKeyDownload = @"UCIsolatedDownload";
UCIsolatedServiceKey UCIsolatedServiceKeyParse = @"UCIsolatedParse";
UCIsolatedServiceKey UCIsolatedServiceKeyVerify = @"UCIsolatedVerify";
UCIsolatedServiceKey UCIsolatedServiceKeyInstall = @"UCIsolatedInstall";

@interface UCIsolatedService () <UCIsolatedServiceProtocol>
@property(strong) NSXPCConnection* service;
@property(strong) NSMutableDictionary<NSUUID*,NSProgress*>* progress;
@property(strong) NSLock* progressLock;

- (instancetype)initWithService:(UCIsolatedServiceKey)inServiceKey withProtocol:(Protocol*)inProtocol;

/** Return identifier associated progress only if it already exists. */
- (NSProgress *)optionalProgressForIdentifier:(NSUUID *)anIdentifier;
@end

@implementation UCIsolatedService

+ (instancetype)service:(UCIsolatedServiceKey)inServiceKey withProtocol:(Protocol*)inProtocol {
	return [(UCIsolatedService*)[[self class] alloc] initWithService:inServiceKey withProtocol:inProtocol];
}

- (instancetype)initWithService:(UCIsolatedServiceKey)inServiceKey withProtocol:(Protocol*)inProtocol {
	NSParameterAssert(inServiceKey != nil);
	NSParameterAssert(inProtocol != nil);
	if ((self = [super init])) {
		// Get service name from framework's Info.plist; compile time derived service name used to ensure unique application namespace 
		NSString* serviceName = [[NSBundle bundleForClass:self.class] objectForInfoDictionaryKey:inServiceKey];
		NSAssert1(serviceName != nil, @"Missing required Info.plist service key: %@",inServiceKey);
		self.progress = [NSMutableDictionary new];
		self.service = [[NSXPCConnection alloc] initWithServiceName:serviceName];
		self.service.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:inProtocol];
		self.service.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UCIsolatedServiceProtocol)];
		self.service.exportedObject = self;
		[self.service resume];
	}
	return self;
}

- (void)dealloc {
	[self.service invalidate];
}

- (id)asyncWithErrorHandler:(void (^)(NSError *error))handler {
	NSParameterAssert(handler != nil);
	return [self.service remoteObjectProxyWithErrorHandler:handler];
}

- (id)syncWithErrorHandler:(void (^)(NSError *error))handler {
	NSParameterAssert(handler != nil);
	return [self.service synchronousRemoteObjectProxyWithErrorHandler:handler];
}

- (NSProgress *)progressForIdentifier:(NSUUID *)anIdentifier {
	[self.progressLock lock];
	NSProgress* p = self.progress[anIdentifier];
	if (p == nil) {
		p = [NSProgress progressWithTotalUnitCount:1];
		self.progress[anIdentifier] = p;
	}
	[self.progressLock unlock];
	return p;
}

- (NSProgress *)optionalProgressForIdentifier:(NSUUID *)anIdentifier {
	[self.progressLock lock];
	NSProgress* p = self.progress[anIdentifier];
	[self.progressLock unlock];
	return p;
}

- (void)removeProgressForIdentifier:(NSUUID *)anIdentifier {
	[self.progressLock lock];
	[self.progress removeObjectForKey:anIdentifier];
	[self.progressLock unlock];
}

#pragma mark - UCIsolatedServiceProtocol

- (void)serviceDidBeginTaskWithIdentifier:(NSUUID*) __unused anIdentifier {
	// Nothing to do; creating NSProgress here is tempting but will not work. This is a different thread to caller.
}

- (void)serviceDidUpdateTaskWithIdentifier:(NSUUID*)anIdentifier completing:(NSInteger)inCompletedUnits ofTotalUnits:(NSInteger)inTotalUnits {
	NSProgress* progress = [self optionalProgressForIdentifier:anIdentifier];
	progress.totalUnitCount = inTotalUnits;
	progress.completedUnitCount = inCompletedUnits;
}

- (void)serviceDidUpdateTaskWithIdentifier:(NSUUID*)anIdentifier message:(NSString* __nullable)aMessage {
	NSProgress* progress = [self optionalProgressForIdentifier:anIdentifier];
	progress.localizedDescription = aMessage;
}

- (void)serviceDidUpdateTaskWithIdentifier:(NSUUID*)anIdentifier detail:(NSString* __nullable)aDetail {
	NSProgress* progress = [self optionalProgressForIdentifier:anIdentifier];
	progress.localizedAdditionalDescription = aDetail;
}

- (void)serviceDidEndTaskWithIdentifier:(NSUUID*)anIdentifier {
	[self removeProgressForIdentifier:anIdentifier];
}

@end

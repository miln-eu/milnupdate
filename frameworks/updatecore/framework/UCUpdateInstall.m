//
//  UCUpdateInstall.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCUpdateInstall.h"
#import "UpdateCorePrivate.h"
#import "UCIsolatedService.h"
#import "UCIsolatedInstallProtocol.h"
#import "UCInstallToolProtocol.h"

NSString* UCUpdateInstallKeyLocalizedProgress = @"localizedProgress";

static NSString* UCUpdateInstallKVOContextProgress = @"UCUpdateInstallKVOContextProgress";

@interface UCUpdateInstall ()
@property(strong,readwrite) NSString* localizedProgress;
@property(assign,readwrite) BOOL isFinished;
@property(strong,readwrite) NSError* error;
// ...
@property(strong) NSOperationQueue* queue;
@property(strong) NSProgress* progress;

+ (UCIsolatedService*)installService;
+ (NSError*)requestAuthorityWithIdentifier:(NSUUID*)anIdentifier;

- (NSError*)launchWithFileAtURL:(NSURL*)aFileURL identifier:(NSUUID*)anIdentifier;
- (void)finishWithError:(NSError*)inError completionHandler:(void(^)(NSError*))inHandler;
@end

@implementation UCUpdateInstall

+ (UCIsolatedService*)installService {
	return [UCIsolatedService service:UCIsolatedServiceKeyInstall withProtocol:@protocol(UCIsolatedInstallProtocol)];
}

+ (NSError*)requestAuthorityWithIdentifier:(NSUUID*)anIdentifier {
	UCIsolatedService* installService = [self.class installService];
	
	// Request authority from the user to install the privileged helper tool
	__block NSError* authorityError = nil;
	[(NSObject<UCIsolatedInstallProtocol>*)[installService syncWithErrorHandler:^(NSError* inServiceError) {
		authorityError = inServiceError;
	}] requestAuthorityWithIdentifier:anIdentifier reply:^(NSError* inAuthorityError) {
		authorityError = inAuthorityError;
	}];
	
	return authorityError;
}

+ (void)requestAuthorityWithQueue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSError* __nullable))inHandler {
	NSOperationQueue* queue = inQueue;
	if (inQueue == nil) {
		queue = UpdateCore.sharedQueue;
	}
	
	NSProgress* progress = [NSProgress progressWithTotalUnitCount:1];
	
	[queue addOperationWithBlock:^{
		
		[progress becomeCurrentWithPendingUnitCount:1];
		NSError* error = [self requestAuthorityWithIdentifier:[NSUUID UUID]];
		[progress resignCurrent];
		
		if (inHandler != nil) {
			inHandler(error);
		}
	}];
}

+ (instancetype)installWithFileURL:(NSURL*)inFileURL queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSError* __nullable))inHandler {
	return [(UCUpdateInstall*)[[self class] alloc] initWithFileURL:inFileURL queue:inQueue completionHandler:inHandler];
}

- (instancetype)initWithFileURL:(NSURL*)inFileURL queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSError* __nullable))inHandler {
	NSParameterAssert(inFileURL != nil);
	if ((self = [super init])) {
		self.queue = inQueue;
		if (inQueue == nil) {
			self.queue = UpdateCore.sharedQueue;
		}
		
		self.progress = [NSProgress progressWithTotalUnitCount:100];
		
		[self.queue addOperationWithBlock:^{
			[self.progress becomeCurrentWithPendingUnitCount:2];
			
			// Establish authority to install
			NSError* authorityError = [[self class] requestAuthorityWithIdentifier:[NSUUID UUID]];
			if (authorityError != nil) {
				[self.progress resignCurrent];
				[self finishWithError:authorityError completionHandler:inHandler];
				return;
			}
			
			[self.progress resignCurrent];
			[self.progress becomeCurrentWithPendingUnitCount:98];
			
			// Perform installation using established authority
			NSError* launchError = [self launchWithFileAtURL:inFileURL identifier:[NSUUID UUID]];
			if (launchError != nil) {
				[self.progress resignCurrent];
				[self finishWithError:launchError completionHandler:inHandler];
				return;
			}
			
			[self.progress resignCurrent];
			[self finishWithError:nil completionHandler:inHandler];
		}];
	}
	return self;
}

- (NSError*)launchWithFileAtURL:(NSURL*)aFileURL identifier:(NSUUID*)anIdentifier {
	// Create bookmarks for URL; this needs to cross process boundaries
	NSError* bookmarkError = nil;
	NSData* fileBookmark = [aFileURL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:&bookmarkError];
	if (bookmarkError != nil) {
		return bookmarkError;
	}
	
	UCIsolatedService* installService = [self.class installService];
	
	// Track install progress
	NSProgress* installProgress = [installService progressForIdentifier:anIdentifier];
	installProgress.kind = NSProgressKindFile;
	[installProgress setUserInfoObject:NSProgressFileOperationKindReceiving forKey:NSProgressFileOperationKindKey];
	[installProgress setUserInfoObject:aFileURL forKey:NSProgressFileURLKey];
	[installProgress setUserInfoObject:@(0) forKey:NSProgressFileCompletedCountKey];
	[installProgress setUserInfoObject:@(1) forKey:NSProgressFileTotalCountKey];
	// ...observe progress detail and propogate to instance property (binding is not available in Foundation)
	NSArray<NSString*>* observedProgressKeys = @[NSStringFromSelector(@selector(localizedAdditionalDescription))];
	for(NSString* keyPath in observedProgressKeys) {
		[installProgress addObserver:self forKeyPath:keyPath options:0 context:(__bridge void * _Nullable)(UCUpdateInstallKVOContextProgress)];
	}
	
	// Launch the tool as with administrator rights in an out-of-bounds process
	__block NSError* installError = nil;
	[(NSObject<UCIsolatedInstallProtocol>*)[installService syncWithErrorHandler:^(NSError* inServiceError) {
		installError = inServiceError;
	}] installWithFile:fileBookmark identifier:anIdentifier withReply:^(NSError* inInstallError) {
		installError = inInstallError;
	}];
	
	// Stop observing progress
	for(NSString* keyPath in observedProgressKeys) {
		[installProgress removeObserver:self forKeyPath:keyPath context:(__bridge void * _Nullable)(UCUpdateInstallKVOContextProgress)];
	}
	
	return installError;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (context == (__bridge void * _Nullable)(UCUpdateInstallKVOContextProgress)) {
		if ([object isKindOfClass:NSProgress.class] == YES) {
			NSProgress* installProgress = object;
			NSString* description = installProgress.localizedAdditionalDescription;
			dispatch_async(dispatch_get_main_queue(), ^{
				self.localizedProgress = description;
			});
		}
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)finishWithError:(NSError*)inError completionHandler:(void(^)(NSError*))inHandler {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.error = inError;
		if (self.error != nil) {
			self.localizedProgress = self.error.localizedDescription;
		}
		self.isFinished = YES;
		if (inHandler != nil) {
			inHandler(inError);
		}
	});
}

@end

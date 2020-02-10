//
//  UKUpdateController.m
//  UpdateKit
//
//  Copyright © 2018 Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import UpdateCore;
#import "UKUpdateController.h"

// Class specific error codes
const NSInteger UKUpdateControllerErrorOpenPackage = 500;

// Info.plist keys
static NSString* UKUpdateControllerInfoPlistKeyBundleRevision = @"CFBundleVersion"; /**< Application revision */
static NSString* UKUpdateControllerInfoPlistKeyDiscoveryURL = @"UKDiscoveryURL"; /**< URL to fetch and parse for available updates. */

// KVO
static NSString* UKUpdateControllerKeyProgress = @"progress";
static NSString* UKUpdateControllerKeyProgressFractionCompleted = @"fractionCompleted";
static NSString* UKUpdateControllerKeyProgressLocalizedDescription = @"localizedDescription";
// ...contexts
static NSString* UKUpdateControllerKVOContextProgress = @"UKUpdateControllerKVOContextProgress";
static NSString* UKUpdateControllerKVOContextProgressState = @"UKUpdateControllerKVOContextProgressState"; 
static NSString* UKUpdateControllerKVOContextProgressLocalized = @"UKUpdateControllerKVOContextProgressLocalized";

/** UKUpdate combines an update with the discoverer's installer block. */
@interface UKUpdate : NSObject <UKAvailableUpdate>
@property(strong) UKUpdateController* updateController;
@property(strong) UCUpdate* update;
- (instancetype)initWithUpdate:(UCUpdate*)inUpdate andController:(UKUpdateController*)inUpdateController;
@end

@interface UKUpdateController ()
@property(strong,readwrite) NSProgress* progress;
@property(strong) NSWindowController* windowController;

@property(assign,readwrite) double uiProgressFractionCompleted;
@property(copy,readwrite) NSString* uiProgressDetail;
@property(copy,readwrite) NSString* uiProgressText;

- (BOOL)updateInProgress;
- (NSProgress*)installUpdate:(UCUpdate*)inUpdate manually:(BOOL)inManually withCompletionHandler:(void(^ __nullable)(NSError* __nullable))inHandler;
@end

@implementation UKUpdateController

- (instancetype)init {
	if ((self = [super init])) {
		// Clear previously cached downloads
		[UCUpdateDownload clearCache];
		
		// Observe progress to propogate values via main-thread to properties. Simplifies user interface binding.
		[self addObserver:self forKeyPath:UKUpdateControllerKeyProgress options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgress)];
	}
	return self;
}

- (void)dealloc {
	self.progress = nil; // stop observing progress
	[self removeObserver:self forKeyPath:UKUpdateControllerKeyProgress context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgress)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (context == (__bridge void * _Nullable)(UKUpdateControllerKVOContextProgress)) {
		// Key paths affecting user interface properties
		NSArray* progressKeyPaths = @[UKUpdateControllerKeyProgressFractionCompleted, UKUpdateControllerKeyProgressLocalizedDescription];
		// Stop observing old progress
		id oldProgress = change[NSKeyValueChangeOldKey];
		if ([oldProgress isKindOfClass:NSProgress.class] == YES) {
			for(NSString* kp in progressKeyPaths) {
				[(NSProgress*)oldProgress removeObserver:self forKeyPath:kp context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressState)];
			}
		}
		// Start observing new progress
		id newProgress = change[NSKeyValueChangeNewKey];
		if ([newProgress isKindOfClass:NSProgress.class] == YES) {
			for(NSString* kp in progressKeyPaths) {
				[(NSProgress*)newProgress addObserver:self forKeyPath:kp options:NSKeyValueObservingOptionInitial context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressState)];
			}
		}
		
	} else if (context == (__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressState)) {
		// Progress has changed, propogate to user interface properties via main thread
		if ([object isKindOfClass:NSProgress.class] == YES) {
			NSProgress* p = (NSProgress*)object;
			dispatch_async(dispatch_get_main_queue(), ^{
				self.uiProgressFractionCompleted = p.fractionCompleted;
				self.uiProgressDetail = p.localizedAdditionalDescription;
				self.uiProgressText = p.localizedDescription;
			});
		}
	} else if (context == (__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressLocalized)) {
		NSString* v = [object valueForKeyPath:keyPath];
		dispatch_async(dispatch_get_main_queue(), ^{
			self.uiProgressDetail = v;
		});
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark -

- (BOOL)updateInProgress {
	return (self.progress != nil && self.progress.isFinished == NO);
}

#pragma mark - Methods without user interface

- (NSProgress*)discoverWithCompletionHandler:(void(^)(NSObject<UKAvailableUpdate>* inUpdate,NSError* inDiscoveryError))inHandler {
	// Get the discovery URL either a property or from the Info.plist.
    if (self.discoveryURL == nil) {
        self.discoveryURL = [NSURL URLWithString:[NSBundle.mainBundle objectForInfoDictionaryKey:UKUpdateControllerInfoPlistKeyDiscoveryURL]];
        if (self.discoveryURL == nil) {
            if (inHandler != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    inHandler(nil, [NSError errorWithDomain:NSStringFromClass(self.class) code:404 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Missing discovery URL. Set programmatically or Info.plist key: %@", UKUpdateControllerInfoPlistKeyDiscoveryURL]}]);
                });
            }
            return nil;
        }

    }
	// Get the application's revision from the Info.plist.
	NSString* revision = [NSBundle.mainBundle objectForInfoDictionaryKey:UKUpdateControllerInfoPlistKeyBundleRevision];
	if (revision == nil) {
		if (inHandler != nil) {
			dispatch_async(dispatch_get_main_queue(), ^{
				inHandler(nil, [NSError errorWithDomain:NSStringFromClass(self.class) code:404 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Missing current revision. Set Info.plist key: %@", UKUpdateControllerInfoPlistKeyBundleRevision]}]);
			});
		}
		return nil;
	}
	
	// Get the operating system version. Used to ignore application updates requiring newer operating system versions.
	NSString* systemVersion = UCUpdateDiscover.systemVersion;
	
	NSProgress* progress = [NSProgress progressWithTotalUnitCount:1];
	self.progress = progress;
	[progress becomeCurrentWithPendingUnitCount:1];
	(void) [UCUpdateDiscover discoverWithURL:self.discoveryURL revision:revision systemVersion:systemVersion queue:nil completionHandler:^(UCUpdate* inUpdate, NSError* inError) {
		// Package up the core update (containing URL) and this instance (providing installation method)
		UKUpdate* update = nil;
		if (inUpdate != nil) {
			update = [[UKUpdate alloc] initWithUpdate:inUpdate andController:self];
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			self.progress = nil;
			inHandler(update, inError);
		});
	}];
	[progress resignCurrent];
	return progress;
}

- (NSProgress*)installUpdate:(UCUpdate*)inUpdate manually:(BOOL)inManually withCompletionHandler:(void(^ __nullable)(NSError* __nullable))inHandler {
	NSProgress* progress = [NSProgress progressWithTotalUnitCount:2];
	self.progress = progress;

	// Ensure authority to install before downloading and wasting bandwidth
	[UCUpdateInstall requestAuthorityWithQueue:nil completionHandler:^(NSError* inAuthorityError) {
		[progress becomeCurrentWithPendingUnitCount:1];

		if (inAuthorityError != nil) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self.progress = nil;
				if (inHandler != nil) {
					inHandler(inAuthorityError);
				}
			});
			return;
		}
		
		// Authority to install has been granted, download
		__block UCUpdateDownload* downloader = nil;
		downloader = [UCUpdateDownload downloadWithRequest:[NSURLRequest requestWithURL:inUpdate.downloadURL] queue:nil completionHandler:^(NSURL* inFileURL, NSString* inCommonName, NSError* inDownloadError) {
			NSLog(@"[%@] Download finished: %@, %@, %@", NSStringFromClass(self.class), inFileURL, inCommonName, inDownloadError);
			[downloader removeObserver:self forKeyPath:UCUpdateDownloadKeyLocalizedProgress context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressLocalized)];
			
			if (inDownloadError == nil) {
				[progress becomeCurrentWithPendingUnitCount:1];
				progress.cancellable = NO;
				progress.pausable = NO;
				
                if (inManually == NO) {
                    __block UCUpdateInstall* installer = nil;
                    installer = [UCUpdateInstall installWithFileURL:downloader.fileURL queue:nil completionHandler:^(NSError* inError) {
                        NSLog(@"[%@] Install finished: %@", NSStringFromClass(self.class), inError);
                        [installer removeObserver:self forKeyPath:UCUpdateInstallKeyLocalizedProgress context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressLocalized)];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.progress = nil;
                            if (inHandler != nil) {
                                inHandler(inError);
                            }
                        });
                    }];
                    [installer addObserver:self forKeyPath:UCUpdateInstallKeyLocalizedProgress options:NSKeyValueObservingOptionInitial context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressLocalized)];
                    
                    [progress resignCurrent];
                } else {
                    // Manual installation; open file package and dimiss update interface
                    BOOL validOpen = [NSWorkspace.sharedWorkspace openURL:downloader.fileURL];
                    NSError* openError = nil;
                    NSLog(@"[%@] Manual install: %@ (%@)", NSStringFromClass(self.class), downloader.fileURL, (validOpen?@"Opened":@"Failed"));
                    if (validOpen == NO) {
                        openError = [NSError errorWithDomain:NSStringFromClass(self.class) code:UKUpdateControllerErrorOpenPackage userInfo:nil];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.progress = nil;
                        if (inHandler != nil) {
                            inHandler(openError);
                        }
                    });
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.progress = nil;
                    if (inHandler != nil) {
                        inHandler(inDownloadError);
                    }
                });
            }
                
		}];
		[downloader addObserver:self forKeyPath:UCUpdateDownloadKeyLocalizedProgress options:NSKeyValueObservingOptionInitial context:(__bridge void * _Nullable)(UKUpdateControllerKVOContextProgressLocalized)];
		
		[progress resignCurrent];
	}];
	
	return progress;
}

@end

@implementation UKUpdate

- (instancetype)initWithUpdate:(UCUpdate*)inUpdate andController:(UKUpdateController*)inUpdateController {
	NSParameterAssert(inUpdate != nil);
	NSParameterAssert(inUpdateController != nil);
	if ((self = [super init])) {
		self.updateController = inUpdateController;
		self.update = inUpdate;
	}
	return self;
}

- (NSProgress*)installWithCompletionHandler:(void(^ __nullable)(NSError* __nullable inInstallError))inHandler {
    return [self.updateController installUpdate:self.update manually:NO withCompletionHandler:inHandler];
}

- (NSProgress*)installManuallyWithCompletionHandler:(void(^ __nullable)(NSError* __nullable inDownloadError))inHandler {
    return [self.updateController installUpdate:self.update manually:YES withCompletionHandler:inHandler];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@[%@]", NSStringFromClass(self.class), self.update.description];
}

@end


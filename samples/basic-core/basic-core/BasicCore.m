//
//  BasicCore.m
//  basic-core
//
//  Copyright © 2018 Graham Miln. All rights reserved.
//

@import UpdateCore;
#import "BasicCore.h"

@interface BasicCore ()
@property(weak) IBOutlet NSWindow* window;
// Discover
@property(weak) IBOutlet NSTextField* versionField;
@property(weak) IBOutlet NSTextField* systemVersionField;
@property(weak) IBOutlet NSTextField* urlField;
@property(strong) UCUpdateDiscover* discover;
// Download
@property(strong) UCUpdateDownload* download;
// Install
@property(strong) UCUpdateInstall* install;
// Shared Progress
@property(weak) IBOutlet NSProgressIndicator* progressIndicator;
@property(weak) IBOutlet NSTextField* progressLabel;
@property(weak) IBOutlet NSTextField* progressAdditionalInfoLabel;
// ...
@property(strong) NSProgress* progress;
- (void)startProgress;
- (void)endProgress;
@end

static NSString* AppDelegateKVOContextProgress = @"AppDelegateKVOContextProgress";

@implementation BasicCore

- (void)applicationWillFinishLaunching:(NSNotification*) __unused aNotification {
	[NSUserDefaults.standardUserDefaults registerDefaults:@{@"exampleSystemVersion": UCUpdateDiscover.systemVersion,@"exampleVersion": @"1.0.0"}];
	
	[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(authorityDidNotify:) name:nil object:@"eu.miln.update" suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}

- (void)authorityDidNotify:(NSNotification*)aNotification {
	NSLog(@"app got notification: %@", aNotification);
}

- (IBAction)discover:(id)aSender {
	[self startProgress];
	NSURL* url = [NSURL URLWithString:self.urlField.stringValue];
	self.discover = [UCUpdateDiscover discoverWithURL:url revision:self.versionField.stringValue systemVersion:self.systemVersionField.stringValue queue:nil completionHandler:^(UCUpdate* inUpdate, NSError* inError) {
		NSLog(@"Discovery finished: %@, %@", inUpdate, inError);
		[self endProgress];
	}];
	[self.progress resignCurrent];
}

- (IBAction)download:(id)aSender {
	[self startProgress];
	self.download = [UCUpdateDownload downloadWithRequest:[NSURLRequest requestWithURL:self.discover.available.downloadURL] queue:nil completionHandler:^(NSURL* inFileURL, NSString* inCommonName, NSError* inError) {
		NSLog(@"Download finished: %@, %@, %@", inFileURL, inCommonName, inError);
		[self endProgress];
	}];
	[self.progress resignCurrent];
}

- (IBAction)install:(id)aSender {
	[self startProgress];
	self.install = [UCUpdateInstall installWithFileURL:self.download.fileURL queue:nil completionHandler:^(NSError* inError) {
		NSLog(@"Install finished: %@", inError);
		[self endProgress];
	}];
	[self.progress resignCurrent];
}

- (IBAction)installSelectedPackage:(id)aSender {
	NSOpenPanel* open = [NSOpenPanel openPanel];
	open.allowedFileTypes = @[@"pkg"];
	[open beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[self startProgress];
			self.install = [UCUpdateInstall installWithFileURL:open.URL queue:nil completionHandler:^(NSError* inError) {
				NSLog(@"Install selected package finished: %@", inError);
				[self endProgress];
			}];
			[self.progress resignCurrent];
		}
	}];
}

- (IBAction)cancel:(id)aSender {
	[self.progress cancel];
}

- (IBAction)reset:(id)aSender {
	[self cancel:aSender];
	self.discover = nil;
	self.download = nil;
}

- (void)startProgress {
	self.progress = [NSProgress progressWithTotalUnitCount:1];
	[self.progress addObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted)) options:NSKeyValueObservingOptionInitial context:(__bridge void * _Nullable)(AppDelegateKVOContextProgress)];
	[self.progress becomeCurrentWithPendingUnitCount:1];
}

- (void)endProgress {
	[self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted)) context:(__bridge void * _Nullable)(AppDelegateKVOContextProgress)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (context == (__bridge void * _Nullable)(AppDelegateKVOContextProgress)) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.progressIndicator.doubleValue = self.progress.fractionCompleted;
			self.progressLabel.stringValue = self.progress.localizedDescription;
			self.progressAdditionalInfoLabel.stringValue = self.progress.localizedAdditionalDescription;
		});
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

@end

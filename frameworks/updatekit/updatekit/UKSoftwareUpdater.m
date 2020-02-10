//
//  UKSoftwareUpdater.m
//  UpdateKit
//
//  Copyright © 2018 Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import UpdateCore;
#import "UKAvailableUpdate.h"
#import "UKSoftwareUpdater.h"
#import "UKUpdateController.h"

// Defaults
// Use `defaults delete eu.miln.update.basic-kit UKSoftwareUpdaterLastCheck` to reset the last check date in the example application
static NSString* UKSoftwareUpdaterDefaultsKeyLastCheck = @"UKSoftwareUpdaterLastCheck"; /**< Time interval since reference date of last check (double) */
static NSString* UKSoftwareUpdaterDefaultsKeyNextCheckInterval = @"UKSoftwareUpdaterNextCheckInterval"; /**< Time interval between automatic checks (double) */
// TODO: Replace defaults with caching headers from discovery; move logic to the server
static NSTimeInterval UKSoftwareUpdaterDefaultsValueNextCheckInterval = (60 * 60 * 24 * 7); /**< Seconds to wait between automatic checks; once a week */
static NSTimeInterval UKSoftwareUpdaterDefaultsValueNextCheckIntervalMinimum = 60; /**< Minimum period to wait between automatic checks; one minute. */

// KVO
static NSString* UKSoftwareUpdaterKeyProgress = @"progress";

// Localised keys
static NSString* UKSoftwareUpdaterLocalisedKeyCheckForUpdatesNoneMessage = @"checkforupdates.none.message"; /* {1} application name */
static NSString* UKSoftwareUpdaterLocalisedKeyCheckForUpdatesNoneInfo = @"checkforupdates.none.info"; /* {1} application name */
static NSString* UKSoftwareUpdaterLocalisedKeyInstallErrorMessage = @"installerror.message"; /* {1} application name {2} error message */
static NSString* UKSoftwareUpdaterLocalisedKeyInstallErrorInfo = @"installerror.info"; /* {1} application name {2} error message */

static NSString* UKSoftwareUpdaterKVOContextProgress = @"UKSoftwareUpdaterKVOContextProgress";

static NSString* UKSoftwareUpdaterLocalizationMessageText = @"softwareavailable.message.fmt"; /* {1} application name (string) */
static NSString* UKSoftwareUpdaterLocalizationInformationText = @"softwareavailable.information.fmt"; /* {1} application name (string) */

@interface UKSoftwareUpdater ()
@property(strong) NSProgress* progress; // Required by NSProgressReporting. Bound to updateController.progress
@property(strong) UKUpdateController* updater;
@property(strong) NSTimer* automatic;
@property(strong) NSObject<UKAvailableUpdate>* availableUpdate;
// ...
@property(strong) NSString* messageText;
@property(strong) NSString* informationText;

/** Check for updates, with optional response in the user interface. */
- (void)checkForUpdatesWithResponse:(BOOL)showResponse;

/** Interval between automatic checks for updates. */
- (NSTimeInterval)nextCheckInterval;

/** Is an update being discovered, downloaded, or installed? */
- (BOOL)isBusy;
@end

@implementation UKSoftwareUpdater

+ (void)initialize {
	// Register reasonable defaults to reduce required configuration
	[NSUserDefaults.standardUserDefaults registerDefaults:@{UKSoftwareUpdaterDefaultsKeyNextCheckInterval:@(UKSoftwareUpdaterDefaultsValueNextCheckInterval)}];
}

- (nonnull instancetype)init {
    if ((self = [super initWithWindow:nil])) {
		// updater (UKUpdateController) does the work that underpins the interface
		self.updater = [UKUpdateController new];
		[self bind:UKSoftwareUpdaterKeyProgress toObject:self.updater withKeyPath:UKSoftwareUpdaterKeyProgress options:nil];
		
		// Schedule automatic checks for updates
		NSDate* nc = self.nextCheck;
		// ...avoid checking immediately
		NSDate* soon = [NSDate dateWithTimeIntervalSinceNow:UKSoftwareUpdaterDefaultsValueNextCheckIntervalMinimum];
		self.automatic = [[NSTimer alloc] initWithFireDate:[nc laterDate:soon] interval:self.nextCheckInterval repeats:YES block:^(NSTimer* inTimer) {
			[self performSelectorOnMainThread:@selector(quietlyCheckForUpdates:) withObject:self waitUntilDone:NO];
		}];
		[NSRunLoop.mainRunLoop addTimer:self.automatic forMode:NSDefaultRunLoopMode];
	}
	return self;
}

/** Return an instance with a specific discovery URL.
 @discussion Use default constructor to read URL from Info.plist. */
- (nonnull instancetype)initWithDiscoveryURL:(nonnull NSURL*)aDiscoveryURL {
    if ((self = [self init])) {
        self.updater.discoveryURL = aDiscoveryURL;
    }
    return self;
}

- (nonnull instancetype)initWithWindow:(NSWindow *)window {
    return [self init];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    return [self init];
}

- (void)dealloc {
	[self.automatic invalidate];
	[self unbind:UKSoftwareUpdaterKeyProgress];
}

#pragma mark -

- (NSNibName)windowNibName {
	return NSStringFromClass(self.class);
}

- (void)windowWillLoad {
	[super windowWillLoad];
	
	// Localised text
	NSBundle* thisBundle = [NSBundle bundleForClass:self.class];
	NSString* thisClass = NSStringFromClass(self.class);
	NSString* applicationName = [[NSFileManager new] displayNameAtPath:NSBundle.mainBundle.bundlePath];
	NSString* msgFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalizationMessageText, thisClass, thisBundle, @"Software update available.");
	self.messageText = [NSString stringWithFormat:msgFmt,applicationName];
	NSString* infoFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalizationInformationText, thisClass, thisBundle, @"App would like to download and install an update.");
	self.informationText = [NSString stringWithFormat:infoFmt,applicationName];
}

#pragma mark -

+ (NSSet<NSString *> *)keyPathsForValuesAffectingNextCheck {
	return [NSSet setWithObjects:@"lastCheck", nil];
}

- (NSDate*)lastCheck {
	NSTimeInterval lastCheckTime = [NSUserDefaults.standardUserDefaults doubleForKey:UKSoftwareUpdaterDefaultsKeyLastCheck];
	NSDate* lastCheckDate = nil;
	if (lastCheckTime != 0) {
		lastCheckDate = [NSDate dateWithTimeIntervalSinceReferenceDate:lastCheckTime];
	}
	return lastCheckDate;
}

- (void)setLastCheck:(NSDate*)lastCheck {
	[NSUserDefaults.standardUserDefaults setDouble:lastCheck.timeIntervalSinceReferenceDate forKey:UKSoftwareUpdaterDefaultsKeyLastCheck];
}

- (NSTimeInterval)nextCheckInterval {
	NSTimeInterval interval = [NSUserDefaults.standardUserDefaults doubleForKey:UKSoftwareUpdaterDefaultsKeyNextCheckInterval];
	if (interval < UKSoftwareUpdaterDefaultsValueNextCheckIntervalMinimum) {
		interval = UKSoftwareUpdaterDefaultsValueNextCheckInterval;
	}
	return interval;
}

- (NSDate*)nextCheck {
	NSDate* lc = self.lastCheck;
	if (lc != nil) {
		return [lc dateByAddingTimeInterval:self.nextCheckInterval];
	} else {
		return [NSDate new];
	}
}

- (BOOL)isBusy {
	// Simplistic interpretation of busy; if anything is in progress, it is busy
	return (self.progress != nil);
}

- (IBAction)checkForUpdates:(id)aSender {
	[self checkForUpdatesWithResponse:YES];
}

- (IBAction)quietlyCheckForUpdates:(id)aSender {
	[self checkForUpdatesWithResponse:NO];
}

- (void)checkForUpdatesWithResponse:(BOOL)showResponse {
	if (self.isBusy == YES) {
		//[self showWindow:aSender]; // TODO: discovery window state
		// Nothing to do, already busy
		return;
	}
	
	// Progress is bound; can ignore returned progress
	(void) [self.updater discoverWithCompletionHandler:^(NSObject<UKAvailableUpdate>* _Nullable inUpdate, NSError * _Nullable inDiscoveryError) {
		self.availableUpdate = inUpdate;
		
		// Note last check date, regardless of an error
		[self setLastCheck:[NSDate new]];
		
		if (inDiscoveryError != nil) {
			// Could report error through a modal or delegate but impact on user is likely unwelcome.
			// [NSApplication.sharedApplication presentError:inDiscoveryError];
			NSLog(@"[ERROR] %@", inDiscoveryError);
			return;
		}
		
		if (inUpdate == nil) {
			if (showResponse == YES) {
				// No update available
				NSAlert* latestAlert = [NSAlert new];
				latestAlert.icon = [NSImage imageNamed:NSImageNameApplicationIcon];
				// ...localise
				NSBundle* thisBundle = [NSBundle bundleForClass:self.class];
				NSString* thisClass = NSStringFromClass(self.class);
				NSString* applicationName = [[NSFileManager new] displayNameAtPath:NSBundle.mainBundle.bundlePath];
				NSString* msgFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalisedKeyCheckForUpdatesNoneMessage, thisClass, thisBundle, @"App is up to date.");
				latestAlert.messageText = [NSString stringWithFormat:msgFmt,applicationName];
				NSString* infoFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalisedKeyCheckForUpdatesNoneInfo, thisClass, thisBundle, @"There are no updates available.");
				latestAlert.informativeText = [NSString stringWithFormat:infoFmt,applicationName];
				// ...block entire application to say nothing is available. Not a great experience but simplest that works.
				(void) [latestAlert runModal];
			}
		} else {
			NSLog(@"[%@] Update found: %@", NSStringFromClass(self.class), inUpdate);
			
			// An update is available
			[self showWindow:self];
		}
	}];
}

- (IBAction)install:(id)aSender	{
	// Progress is bound; can ignore returned progress
	(void) [self.availableUpdate installWithCompletionHandler:^(NSError* _Nullable inInstallError) {
		NSLog(@"[%@] Install finished: %@", NSStringFromClass(self.class), inInstallError);
		self.progress = nil;
		
		if (inInstallError == nil) {
			// Installation was successful; installer should relaunch or present success interface
			[self close];
		} else {
			// TODO: Ideally use presentError and offer a means of recovery.
			NSAlert* installAlert = [NSAlert new];
			// ...localise
			NSBundle* thisBundle = [NSBundle bundleForClass:self.class];
			NSString* thisClass = NSStringFromClass(self.class);
			NSString* applicationName = [[NSFileManager new] displayNameAtPath:NSBundle.mainBundle.bundlePath];
			NSString* msgFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalisedKeyInstallErrorMessage, thisClass, thisBundle, @"Installation failed.");
			installAlert.messageText = [NSString stringWithFormat:msgFmt,applicationName,inInstallError.localizedDescription];
			NSString* infoFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalisedKeyInstallErrorInfo, thisClass, thisBundle, @"Unable to install the new software.");
			installAlert.informativeText = [NSString stringWithFormat:infoFmt,applicationName,inInstallError.localizedDescription];
			[installAlert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse __unused inReturnCode) {
				// Close the software update window
				[self close];
			}];
		}
	}];
}

- (IBAction)installManually:(id)aSender {
    // Progress is bound; can ignore returned progress
    (void) [self.availableUpdate installManuallyWithCompletionHandler:^(NSError* _Nullable inInstallError) {
        NSLog(@"[%@] Manual install finished: %@", NSStringFromClass(self.class), inInstallError);
        self.progress = nil;
        
        if (inInstallError == nil) {
            // Installation was successful; installer should relaunch or present success interface
            [self close];
        } else {
            NSAlert* installAlert = [NSAlert new];
            // ...localise
            NSBundle* thisBundle = [NSBundle bundleForClass:self.class];
            NSString* thisClass = NSStringFromClass(self.class);
            NSString* applicationName = [[NSFileManager new] displayNameAtPath:NSBundle.mainBundle.bundlePath];
            NSString* msgFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalisedKeyInstallErrorMessage, thisClass, thisBundle, @"Installation failed.");
            installAlert.messageText = [NSString stringWithFormat:msgFmt,applicationName,inInstallError.localizedDescription];
            NSString* infoFmt = NSLocalizedStringFromTableInBundle(UKSoftwareUpdaterLocalisedKeyInstallErrorInfo, thisClass, thisBundle, @"Unable to install the new software.");
            installAlert.informativeText = [NSString stringWithFormat:infoFmt,applicationName,inInstallError.localizedDescription];
            [installAlert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse __unused inReturnCode) {
                // Close the software update window
                [self close];
            }];
        }
    }];
}

- (IBAction)cancel:(id)aSender {
	[self.progress cancel];
}

- (BOOL)validateMenuItem:(NSMenuItem *)inMenuItem {
	return [self validateUserInterfaceItem:inMenuItem];
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)inItem {
	if ((inItem.action == @selector(checkForUpdates:)) ||
		([inItem action] == @selector(install:)) ||
		([inItem action] == @selector(cancel:))) {
		return !self.isBusy;
	}
	return NO;
}

@end

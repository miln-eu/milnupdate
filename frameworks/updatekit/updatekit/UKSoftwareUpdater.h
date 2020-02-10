//
//  UKSoftwareUpdater.h
//  UpdateKit
//
//  Copyright © 2018 Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Cocoa;

/** UKSoftwareUpdater provides a reasonable minimum software update interface. For most applications, this will be enough. */
NS_CLASS_AVAILABLE_MAC(10_12)
@interface UKSoftwareUpdater : NSWindowController <NSUserInterfaceValidations,NSProgressReporting>
@property(readonly,nullable) NSDate* lastCheck; /**< Date last checked for updates. nil if never checked. */
@property(readonly,nullable) NSDate* nextCheck; /**< Date next check for updates will be scheduled. nil if check disabled. */

/** Return an instance relying on Info.plist settings. */
- (nonnull instancetype)init NS_DESIGNATED_INITIALIZER;

/** Return an instance using the discovery URL. */
- (nonnull instancetype)initWithDiscoveryURL:(nonnull NSURL*)aDiscoveryURL;

/** Check for available updates and, if found, prompt to install, otherwise tell user no update available. */
- (IBAction)checkForUpdates:(nullable id)aSender;

/** Check for available updates and, only if found, prompt to install. */
- (IBAction)quietlyCheckForUpdates:(nullable id)aSender;

- (IBAction)install:(nullable id)aSender;
- (IBAction)installManually:(nullable id)aSender;
- (IBAction)cancel:(nullable id)aSender;

@end

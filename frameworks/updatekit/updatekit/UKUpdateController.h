//
//  UKUpdateController.h
//  UpdateKit
//
//  Copyright © 2018 Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Cocoa;
#import "UKAvailableUpdate.h"

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger UKUpdateControllerErrorOpenPackage;

/** UKUpdateController provides a default controller for discovering,
 downloading, and installing packaged updates. Use this class to build
 your own software update user interface.
 
 For a pre-built solution, see UKSoftwareUpdater */
@interface UKUpdateController : NSObject <NSProgressReporting>
// ...properties for programmatic configuration
@property(copy) NSURL* discoveryURL; /**< URL of update feed to fetch and parse during discovery; alternatively set Info.plist key `UKDiscoveryURL` */
// ...progress tracking
@property(readonly) NSProgress* progress; /**< Update progress. KVO suitable but not for interface bindings (changes on non-main thread). Use ui… properties for interface bindings. */
@property(readonly) double uiProgressFractionCompleted; /**< User interface suitable binding for progress indicator's value. 0..1 range. */
@property(readonly) NSString* uiProgressText; /**< User interface suitable binding for progress information. */
@property(readonly) NSString* uiProgressDetail; /**< User interface suitable binding for progress label. */

/** Discover best available update.
 @discussion Uses Info.plist 'UKUpdateFeed' or feed property for the URL
 to download and parse. Version comparison is performed using the main
 bundle's CFBundleVersion for revision and the operating system version.
 @param inHandler Block to call when discovery finishes. Called on the main thread.
 @return Progress for tracking the discovery. */
- (NSProgress* __nullable)discoverWithCompletionHandler:(void(^ __nullable)(NSObject<UKAvailableUpdate>* __nullable inUpdate,NSError* __nullable inDiscoveryError))inHandler;

@end

NS_ASSUME_NONNULL_END

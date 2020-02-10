//
//  UKUpdate.h
//  UpdateKit
//
//  Copyright © 2018 Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@protocol UKAvailableUpdate

/**
 Download the update and attempt to install using a privileged helper tool.
 */
- (NSProgress*)installWithCompletionHandler:(void(^ __nullable)(NSError* __nullable inInstallError))inHandler;

/**
 Download the update and prompt the user to install the update manually.
 @discussion
 Manual installation downloads the installation package and opens it. No attempt is made to install the package for the user. This approach avoids
 the need for privileged helper tools and allows the entire application to be sandboxed. This comes at the cost of requiring the user to step through
 macOS's Installer interface.
 */
- (NSProgress*)installManuallyWithCompletionHandler:(void(^ __nullable)(NSError* __nullable inDownloadError))inHandler;
@end

NS_ASSUME_NONNULL_END

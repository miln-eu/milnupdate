//
//  UCInstallController.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;
#import "UCInstallToolProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface UCInstallController : NSObject <UCInstallToolProtocol>
@property(strong) NSString* executablePath; /**< Path to this executable. */
@property(weak) NSXPCConnection* connection; // Weak to avoid retain cycle; this is a retained delegate of the connection
@end

NS_ASSUME_NONNULL_END

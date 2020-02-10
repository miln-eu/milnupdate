//
//  UCIsolatedInstall.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Cocoa;
#import "UCIsolatedInstallProtocol.h"

@interface UCIsolatedInstall : NSObject <UCIsolatedInstallProtocol>
@property(weak) NSXPCConnection* connection;

- (void)cancel;
@end
//
//  UCIsolatedDownload.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;
#import "UCIsolatedDownloadProtocol.h"

/** UCIsolatedDownload service provides a sandboxed process for dealing with the network. */
@interface UCIsolatedDownload : NSObject <UCIsolatedDownloadProtocol>
@property(weak) NSXPCConnection* xpcConnection; // This property is a weak reference because the connection will retain this object, so we don't want to create a retain cycle.

/** Cancel all ongoing downloads. */
- (void)cancelAll;

@end

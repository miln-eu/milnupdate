//
//  UpdateAuthority.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Cocoa;

/** UpdateAuthority is a non-sandboxed application that obtains authorization from the user
 to install new software. When granted authorization, an embedded tool is blessed and installed
 as a privileged helper. It is the privileged helper that handles installation.
 */
@interface UpdateAuthority : NSObject <NSApplicationDelegate>
@end


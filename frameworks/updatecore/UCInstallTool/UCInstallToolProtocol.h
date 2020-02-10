//
//  UCInstallToolProtocol.h
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

/** UCInstallToolProtocol are services offered by the installer tool. */
@protocol UCInstallToolProtocol
/** Compatibility version number. Use to detect API breaking changes in this protocol. */
- (void)compatibleVersionWithReply:(void (^)(NSNumber* inCompatibleVersion))reply;

/** Install a package.
 @param aPackageBookmark Installer package to install.
 @param anIdentifier Unique identifier to track the installation progress by.
 */
- (void)installPackageFile:(NSData*)aPackageBookmark identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSTaskTerminationReason inInstallerTerminationReason, NSInteger inInstallerTerminationStatus, NSError* __nullable inError))reply;

/** Remove the executable at arg[0]. Apple deprecated SMJobRemove in macOS 10.6 but provided no replacement by macOS 10.13. */
- (void)removeToolWithReply:(void (^)(NSError* __nullable inError))reply;
@end

/** UCInstallToolProgressProtocol permits progress tracking of ongoing installations. */
@protocol UCInstallToolProgressProtocol
- (void)installWithIdentifier:(NSUUID*)anIdentifier didBeginWithProcessIdentifier:(NSInteger)inProcessIdentifier stdOut:(NSFileHandle*)inStdOutput stdErr:(NSFileHandle*)inStdError;
@end

NS_ASSUME_NONNULL_END


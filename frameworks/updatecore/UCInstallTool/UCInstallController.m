//
//  UCInstallController.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCInstallController.h"

/* WARNING: This is a privileged tool running with elevated rights. Write minimal and simple code. Do not be clever. */

static NSString* UCInstallControllerInstallerPath = @"/usr/sbin/installer"; /**< Hardcoded path to macOS's installer tool. Never pass a caller provided or runtime determined path for the executable; that would be an unacceptable security risk. */

@implementation UCInstallController

- (void)compatibleVersionWithReply:(void (^)(NSNumber* inCompatibleVersion))reply {
	reply(@(1));
}

- (void)installPackageFile:(NSData*)aPackageBookmark identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSTaskTerminationReason,NSInteger,NSError*))reply {
	// Resolve the package bookmark
	NSError* bookmarkError = nil;
	NSURL* packageURL = [NSURL URLByResolvingBookmarkData:aPackageBookmark options:0 relativeToURL:nil bookmarkDataIsStale:nil error:&bookmarkError];
	if (bookmarkError != nil) {
		reply(0, 0, bookmarkError);
		return;
	} else if (packageURL == nil) {
		reply(0, 0, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:@"Invalid package bookmark."}]);
		return;
	}
	NSString* packagePath = packageURL.path;
	
	// Ensure the package to exists
	NSFileManager* fm = [NSFileManager new];
	if ([fm fileExistsAtPath:packagePath] == NO) {
		reply(0, 0, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid package path: %@",packagePath]}]);
		return;
	}
	
	// Ensure the installer exists
	if ([fm isExecutableFileAtPath:UCInstallControllerInstallerPath] == NO) {
		reply(0, 0, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid installer path: %@",UCInstallControllerInstallerPath]}]);
		return;
	}
	
	// Create a new installer task
	NSTask* installerTask = [NSTask new];
	// ...set the executable
	if (@available(macOS 10.13, *)) {
		NSURL* installerURL = [NSURL fileURLWithPath:UCInstallControllerInstallerPath];
		if (installerURL == nil) {
			reply(0, 0, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid installer URL: %@",UCInstallControllerInstallerPath]}]);
			return;
		}
		installerTask.executableURL = installerURL;
	} else {
		installerTask.launchPath = UCInstallControllerInstallerPath;
	}
	// ...set the arguments
	installerTask.arguments = @[@"-verboseR", // extended output with percentage complete and easy parsing format
								@"-package", // absolute path to package
								packagePath,
								@"-target", // target volume...
								@"/"]; // ...always boot volume
	// ...pass out stdout and stderr to caller
	NSPipe* stdoutPipe = [NSPipe new];
	installerTask.standardOutput = stdoutPipe;
	NSFileHandle* stdoutHandle = stdoutPipe.fileHandleForReading;
	// ....
	NSPipe* stderrPipe = [NSPipe new];
	installerTask.standardError = stderrPipe;
	NSFileHandle* stderrHandle = stderrPipe.fileHandleForReading;
	
	// Launch the task
	if (@available(macOS 10.13, *)) {
		NSError* launchError = nil;
		BOOL validLaunch = [installerTask launchAndReturnError:&launchError];
		if (launchError != nil) {
			reply(0, 0, launchError);
			return;
		} else if (validLaunch == NO) {
			reply(0, 0, [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:@"installer launch failed."}]);
			return;
		}
	} else {
		// Fallback for pre-macOS 10.13
		[installerTask launch];
	}
	
	// Ensure this process is not terminated if the only connected application is itself terminated by the installion
	[NSProcessInfo.processInfo disableSuddenTermination];
	
	// Provide the caller with everything they need to monitor the installation
	[(NSObject<UCInstallToolProgressProtocol>*)[self.connection remoteObjectProxy] installWithIdentifier:anIdentifier didBeginWithProcessIdentifier:installerTask.processIdentifier stdOut:stdoutHandle stdErr:stderrHandle];
	
	// Wait until the installer exits
	[installerTask waitUntilExit];

	[NSProcessInfo.processInfo enableSuddenTermination];
	
	reply(installerTask.terminationReason, installerTask.terminationStatus, nil);
}

- (void)removeToolWithReply:(void (^)(NSError*))reply {
	if (self.executablePath != nil) {
		NSError* removeError = nil;
		(void) [[NSFileManager new] removeItemAtPath:self.executablePath error:&removeError];
		reply(removeError);
	} else {
		reply([NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:nil]);
	}
}

@end

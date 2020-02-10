//
//  UCIsolatedInstall.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCIsolatedInstall.h"
#import "UCInstallToolProtocol.h"
#import "UCIsolatedServiceProtocol.h"
#import "UCLineReader.h"

// Info.plist key
static NSString* UCIsolatedInstallInfoPlistKeyInstallAuthorityApp = @"UCInstallAuthorityApp";

static NSString* UCIsolatedInstallKeyTerminated = @"terminated";
static NSString* UCIsolatedInstallKVOContextAuthorityTerminated = @"UCIsolatedInstallKVOContextAuthorityTerminated";

// Installer output tokens
static NSString* UCIsolatedInstallOutputInstallerPrefixPercentage = @"installer:%"; // followed by a float
static NSString* UCIsolatedInstallOutputInstallerPrefixStatus = @"installer:STATUS:"; // followed by a string
static NSString* UCIsolatedInstallOutputInstallerPrefixPhase = @"installer:PHASE:"; // followed by a string

@interface UCIsolatedInstall () <UCInstallToolProgressProtocol>
@property(strong) dispatch_semaphore_t pendingAuthority;
@property(strong) NSNotification* authorityNotification;
@property(strong) NSMutableDictionary<NSUUID*,NSArray<UCLineReader*>*>* lineReaders; /**< Active line readers. */

- (NSXPCConnection*)toolService;
- (NSObject<UCIsolatedServiceProtocol>*)client;
@end

@implementation UCIsolatedInstall

- (instancetype)init {
	if ((self = [super init])) {
		self.lineReaders = [NSMutableDictionary new];
	}
	return self;
}

- (NSXPCConnection*) toolService {
	// Get mach service name from Info.plist
	NSString* serviceName = nil;
	// SMPrivilegedExecutables appears to be required for process installing privileged job but not those only communicating.
	// This may well change after macOS 10.13 and thus we also include an SMPrivilegedExecutables entry for this XPC service.
	NSObject* potentialDictionary = [NSBundle.mainBundle objectForInfoDictionaryKey:@"SMPrivilegedExecutables"];
	NSObject* firstItem = [[(NSDictionary*)potentialDictionary allKeys] firstObject];
	if ([firstItem isKindOfClass:NSString.class] == YES) {
		serviceName = (NSString*)firstItem;
	}
	if (serviceName == nil) {
		return nil;
	}
	
	NSXPCConnection* service = [[NSXPCConnection alloc] initWithMachServiceName:serviceName options:0];
	service.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UCInstallToolProtocol)];
	service.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UCInstallToolProgressProtocol)];
	service.exportedObject = self;
	[service resume];
	return service;
}

- (void)requestAuthorityWithIdentifier:(NSUUID*)anIdentifier reply:(void (^)(NSError* __nullable inError))reply {
	NSXPCConnection* service = [self toolService];
	if (service == nil) {
		reply([NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:@"Missing service name."}]);
		return;
	}
	
	// Determine if installer tool is available by checking for tool version
	__block NSInteger version = 0;
	__block NSError* versionError = nil;
	[[service synchronousRemoteObjectProxyWithErrorHandler:^(NSError* inServiceError) {
		versionError = inServiceError;
	}] compatibleVersionWithReply:^(NSNumber *inCompatibleVersion) {
		version = inCompatibleVersion.integerValue;
	}];
	if (versionError != nil) {
		// Obtain required rights before continuing; must be done through a non-sandboxed graphical application
		NSString* authorityAppName = [NSBundle.mainBundle objectForInfoDictionaryKey:UCIsolatedInstallInfoPlistKeyInstallAuthorityApp];
		if (authorityAppName == nil) {
			reply([NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:@{NSLocalizedDescriptionKey:@"Missing required authority app Info.plist entry."}]);
			return;
		}
		NSURL* updateAuthorityURL = [[NSBundle bundleForClass:self.class] URLForResource:authorityAppName withExtension:@"app"];
		if (updateAuthorityURL == nil) {
			reply([NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:@{NSLocalizedDescriptionKey:@"Missing required authority application."}]);
			return;
		}
		NSString* authorityIdentifier = [NSBundle bundleWithURL:updateAuthorityURL].bundleIdentifier;
		
		// Wait for authority app to terminate, based on exit code determine success
		self.pendingAuthority = dispatch_semaphore_create(0);
		[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(authorityDidNotify:) name:anIdentifier.UUIDString object:authorityIdentifier suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
		
		NSError* error = nil;
		NSRunningApplication* updateAuthority = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:updateAuthorityURL
																							  options:NSWorkspaceLaunchWithoutAddingToRecents
																						configuration:@{NSWorkspaceLaunchConfigurationArguments:@[@"-uuid",anIdentifier.UUIDString]}
																								error:&error];
		if (updateAuthority == nil) {
			reply([NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:@{NSLocalizedDescriptionKey:@"Unable to launch authority application."}]);
			return;
		}
		
		// Wait for authority app to notify
		dispatch_semaphore_wait(self.pendingAuthority, DISPATCH_TIME_FOREVER);
		
		[NSDistributedNotificationCenter.defaultCenter removeObserver:self];
		
		// Any user information associated with the notification indicates an error
		if (self.authorityNotification.userInfo.allKeys.count > 0) {
			// Look for first string value; highly likely to be an error description
			NSString* msg = nil;
			for(NSObject* value in self.authorityNotification.userInfo.allValues) {
				if (msg == nil && [value isKindOfClass:NSString.class]) {
					msg = (NSString*)value;
				}
			}
			if (msg == nil) {
				msg = @"Authority denied";
			}
			NSLog(@"Update Authority Error: %@", self.authorityNotification.userInfo);
			reply([NSError errorWithDomain:NSPOSIXErrorDomain code:EPERM userInfo:@{NSLocalizedDescriptionKey:msg}]);
			return;
		}
	}
	
	reply(nil);
}

- (void)authorityDidNotify:(NSNotification*)inNotification {
	// Stop waiting, the notification has arrived
	self.authorityNotification = inNotification;
	dispatch_semaphore_signal(self.pendingAuthority);
}

- (void)installWithFile:(NSData*)aFileBookmark identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSError* __nullable inError))reply {
	// Request the installation via privileged tool
	NSXPCConnection* service = [self toolService];
	if (service == nil) {
		reply([NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:@"Missing service name."}]);
		return;
	}
	
	__block NSError* installError = nil;
	[[service synchronousRemoteObjectProxyWithErrorHandler:^(NSError* inError) {
		installError = inError;
	}] installPackageFile:aFileBookmark identifier:anIdentifier withReply:^(NSTaskTerminationReason inInstallerTerminationReason, NSInteger inInstallerTerminationStatus, NSError * _Nullable inError) {
		if (inError == nil) {
			// Only EXIT_SUCCESS is success
			if ( ! ((inInstallerTerminationReason == NSTaskTerminationReasonExit) && (inInstallerTerminationStatus == EXIT_SUCCESS))) {
				installError = [NSError errorWithDomain:NSStringFromClass(self.class)
												   code:inInstallerTerminationStatus
											   userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Installation failed: %ld/%ld",(long)inInstallerTerminationReason,(long)inInstallerTerminationStatus]}];
			}
		} else {
			installError = inError;
		}
	}];
	
	// Discard any associated line readers
	for (UCLineReader* lr in self.lineReaders[anIdentifier]) {
		[lr readAvailable];
	}
	self.lineReaders[anIdentifier] = nil;
	
	[self.client serviceDidEndTaskWithIdentifier:anIdentifier];
	
	reply(installError);
}

- (NSObject<UCIsolatedServiceProtocol>*)client {
	return (NSObject<UCIsolatedServiceProtocol>*)[self.connection remoteObjectProxy];
}

- (void)installWithIdentifier:(NSUUID*)anIdentifier didBeginWithProcessIdentifier:(NSInteger)inProcessIdentifier stdOut:(NSFileHandle*)inStdOutput stdErr:(NSFileHandle*)inStdError {
	[self.client serviceDidBeginTaskWithIdentifier:anIdentifier];
	UCLineReader* stdoutReader = [[UCLineReader alloc] initWithFileHandle:inStdOutput reader:^(NSFileHandle* __unused inFileHandle, NSString* inLine) {
		// Parse the `verboseR` output from `installer`; look for prefixes
		if ([inLine hasPrefix:UCIsolatedInstallOutputInstallerPrefixPercentage] == YES) {
			NSScanner* scanner = [NSScanner scannerWithString:inLine];
			scanner.scanLocation = UCIsolatedInstallOutputInstallerPrefixPercentage.length;
			double latest;
			if ([scanner scanDouble:&latest] == YES) {
				[self.client serviceDidUpdateTaskWithIdentifier:anIdentifier completing:(NSInteger)latest ofTotalUnits:100];
			}
		} else if ([inLine hasPrefix:UCIsolatedInstallOutputInstallerPrefixStatus] == YES) {
			NSString* latest = [inLine substringFromIndex:UCIsolatedInstallOutputInstallerPrefixStatus.length];
			latest = [latest stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
			if (latest.length > 0) {
				[self.client serviceDidUpdateTaskWithIdentifier:anIdentifier message:latest];
			} else {
				[self.client serviceDidUpdateTaskWithIdentifier:anIdentifier message:nil];
			}
		} else if ([inLine hasPrefix:UCIsolatedInstallOutputInstallerPrefixPhase] == YES) {
			NSString* latest = [inLine substringFromIndex:UCIsolatedInstallOutputInstallerPrefixPhase.length];
			latest = [latest stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
			if (latest.length > 0) {
				[self.client serviceDidUpdateTaskWithIdentifier:anIdentifier detail:latest];
			} else {
				[self.client serviceDidUpdateTaskWithIdentifier:anIdentifier detail:nil];
			}
		}
	}];
	UCLineReader* stderrReader = [[UCLineReader alloc] initWithFileHandle:inStdError reader:^(NSFileHandle* __unused inFileHandle, NSString* inLine) {
		// Ignored but could be logged to file?
		//if ([inLine isEqualToString:@""] == NO) {
		//	NSLog(@"installer[stderr]: %@",inLine);
		//}
	}];
	self.lineReaders[anIdentifier] = @[stdoutReader, stderrReader];
}

- (void)cancel {
	if (self.pendingAuthority != nil) {
		dispatch_semaphore_signal(self.pendingAuthority);
		self.pendingAuthority = nil;
	}
}
	

@end

//
//  UpdateAuthority.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import ServiceManagement;
#import "UpdateAuthority.h"
#import "UCAuthorization.h"

@interface UpdateAuthority ()
- (void)launchUpdateAndTerminate;
- (BOOL)installTool:(NSString*)toolLabel error:(NSError**)outError;
@end

@implementation UpdateAuthority

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	// Push the application forward to become active
	[[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[self launchUpdateAndTerminate];
	});
}

- (void)launchUpdateAndTerminate {
	// Ensure a notification name has been provided
	NSString* uniqueNotification = [NSUserDefaults.standardUserDefaults stringForKey:@"uuid"];
	NSParameterAssert(uniqueNotification != nil);
	
	// Get tool label from this application's Info.plist
	NSString* toolLabel = nil;
	NSObject* potentialDictionary = [NSBundle.mainBundle objectForInfoDictionaryKey:@"SMPrivilegedExecutables"];
	NSObject* firstItem = [[(NSDictionary*)potentialDictionary allKeys] firstObject];
	if ([firstItem isKindOfClass:NSString.class] == YES) {
		toolLabel = (NSString*)firstItem;
	}
	
	// Request user permission to install a privileged tool
	NSError* launchError = nil;
	BOOL validLaunch = [self installTool:toolLabel error:&launchError];
	
	// Broadcast notification using command line argument `uuid` for the name
	NSMutableDictionary<NSString*,NSObject*>* info = [NSMutableDictionary new];
	if (launchError != nil) {
		// Any values within info indicate an error
		info[@"error-localizedDescription"] = launchError.localizedDescription;
		info[@"error-code"] = @(launchError.code);
	}
	[NSDistributedNotificationCenter.defaultCenter postNotificationName:uniqueNotification object:NSBundle.mainBundle.bundleIdentifier userInfo:info options:NSDistributedNotificationDeliverImmediately|NSDistributedNotificationPostToAllSessions];

	if (launchError != nil) {
		NSLog(@"[UpdateAuthority] Error installing tool: %@", launchError);
		exit((int)launchError.code);
	} else if (validLaunch == NO) {
		exit(EXIT_FAILURE);
	}
	
	[NSApp terminate:self];
}

- (BOOL)installTool:(NSString*)toolLabel error:(NSError**)outError {
	NSParameterAssert(toolLabel != nil);
	
	// Obtain required rights
	NSError* authError = nil;
	UCAuthorization* authority = [UCAuthorization authorizationWithRights:@[[NSString stringWithUTF8String:kSMRightBlessPrivilegedHelper]] prompt:nil error:&authError];
	if (authError != nil) {
		if (outError != nil) {
			*outError = authError;
		}
		return NO;
	} else if (authority == nil) {
		if (outError != nil) {
			*outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EACCES userInfo:@{NSLocalizedDescriptionKey:@"Authorization denied."}];
		}
		return NO;
	}
	
	// Install the verified helper tool in /Library/PrivilegedHelperTools and the tool's embedded launchd job ticket in /Library/LaunchDaemons
	CFErrorRef blessError = nil;
	bool validBless = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)toolLabel, authority.authorization, &blessError);
	if (blessError != nil) {
		if (outError != nil) {
			*outError = CFBridgingRelease(blessError);
		}
		return NO;
	}
	return validBless;
}

@end

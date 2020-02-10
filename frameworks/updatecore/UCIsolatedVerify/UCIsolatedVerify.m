//
//  UCIsolatedVerify.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCIsolatedVerify.h"

static NSString* UCIsolatedVerifyReportVerdict = @"assessment:verdict";
static NSString* UCIsolatedVerifyReportOriginator = @"assessment:originator";

@implementation UCIsolatedVerify

// Confirm the file is a signed package
//
// `SecStaticCodeCreateWithPath` does not work with packages, only code. So `SecCodeCheckValidityWithErrors` is not available to us.
//
// `spctl` tool can verify packages with the `-type install` flag. The open source code reveals tool uses a System Programming Interface (SPI)
// SecAssessmentRef for this. The code is within libsecurity_codesigning and not available for us to link against.
//
// That leaves the pragmatic approach of calling out to `spctl` directly and parsing the `raw` property list output. Doing this from a
// sandboxed process returns an error because `spctl` can not communicate with its own XPC service. Sandboxing has removed the ability
// to verify if a package file contains a valid signature.
//
// On macOS 10.13, package verification can only be performed by a non-sandboxed process.

- (void)verifyPackageAtURL:(NSURL *)inPackageURL withReply:(void (^)(NSString*, NSError*))reply {
	
	NSTask* spctlTask = [NSTask new];
	spctlTask.launchPath = @"/usr/sbin/spctl"; // macOS 10.3: executableURL
	spctlTask.arguments = @[@"--assess",@"--verbose",@"--verbose",@"--raw",@"--type",@"install",inPackageURL.path];
	NSPipe* pipe = [NSPipe pipe];
	spctlTask.standardOutput = pipe;
	[spctlTask launch]; // macOS 10.3: launchAndReturnError
	NSData* spctlData = [[pipe fileHandleForReading] readDataToEndOfFile];
	[spctlTask waitUntilExit];
	
	if (spctlTask.terminationReason != NSTaskTerminationReasonExit || spctlTask.terminationStatus != 0) {
		reply(nil, [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecServiceNotAvailable userInfo:nil]);
		return;
	}
	
	// Decode and examine the 'raw' property list output; example output is below
	NSError* spctlError = nil;
	id potentialReport = [NSPropertyListSerialization propertyListWithData:spctlData options:NSPropertyListImmutable format:nil error:&spctlError];
	if (spctlError != nil) {
		reply(nil, spctlError);
		return;
	}
	
	if ([potentialReport isKindOfClass:NSDictionary.class] == NO) {
		reply(nil, [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecBadReq userInfo:@{NSLocalizedDescriptionKey:@"[verify] spctl: root must be a dictionary"}]);
		return;
	}
	NSDictionary<NSString*,NSObject*>* report = potentialReport;
	
	BOOL verdict = NO;
	if ([report[UCIsolatedVerifyReportVerdict] respondsToSelector:@selector(boolValue)] == NO) {
		reply(nil, [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecBadReq userInfo:@{NSLocalizedDescriptionKey:@"[verify] spctl: verdict must be a boolean"}]);
		return;
	} else {
		verdict = [(NSNumber*)report[UCIsolatedVerifyReportVerdict] boolValue];
	}
	if (verdict == NO) {
		reply(nil, [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecInvalidSignature userInfo:nil]);
		return;
	}
	
	NSObject* potentialOriginator = report[UCIsolatedVerifyReportOriginator];
	if ([potentialOriginator isKindOfClass:NSString.class] == NO) {
		// Verdict was valid but report format unexpected, treat as an error
		reply(nil, [NSError errorWithDomain:NSOSStatusErrorDomain code:errSecBadReq userInfo:@{NSLocalizedDescriptionKey:@"[verify] spctl: originator must be a string"}]);
		return;
	}
	
	reply((NSString*)potentialOriginator, nil);
}

@end

// # Example output from `spctl --raw -vv`
//
// <?xml version="1.0" encoding="UTF-8"?>
// <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
// <plist version="1.0">
// 	<dict>
// 		<key>assessment:authority</key>
// 		<dict>
// 			<key>assessment:authority:flags</key>
// 			<integer>0</integer>
// 			<key>assessment:authority:row</key>
// 			<integer>7</integer>
// 			<key>assessment:authority:source</key>
// 			<string>Developer ID</string>
// 		</dict>
// 		<key>assessment:originator</key>
// 		<string>Developer ID Installer: My Company (ABC)</string>
// 		<key>assessment:remote</key>
// 		<true/>
// 		<key>assessment:verdict</key>
// 		<true/>
// 	</dict>
// </plist>

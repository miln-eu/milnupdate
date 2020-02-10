//
//  UCUpdateDiscover.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCUpdateDiscover.h"
#import "UCIsolatedService.h"
#import "UCIsolatedDownloadProtocol.h"
#import "UCIsolatedParseProtocol.h"
#import "UCVersionComparison.h"
#import "UpdateCorePrivate.h"

@interface UCUpdateDiscover ()
@property(assign,readwrite) BOOL isFinished;
@property(strong,readwrite) NSError* error;
@property(strong,readwrite) UCUpdate* available;
// ...
@property(copy) NSURL* discoveryURL; /**< URL of update discovery. */
@property(strong) NSOperationQueue* queue; /**< Queue to fetch, parse, and process on. */
@property(strong) NSProgress* progress;

- (NSData*)dataWithContentsOfURL:(NSURL*)aURL error:(NSError**)outError;
- (UCIsolatedParseArrayEntries)parseDiscoveryData:(NSData*)someData error:(NSError**)outError;
- (UCIsolatedParseEntry)evaluateEntries:(UCIsolatedParseArrayEntries)someEntries revision:(NSString*)inRevision systemVersion:(NSString*)inSystemVersion error:(NSError**)outError;

- (UCIsolatedParseArrayEntries)filterEntries:(UCIsolatedParseArrayEntries)someEntries forKey:(NSString*)inKey withValue:(NSString*)inValue comparator:(NSObject<UCVersionComparisonProtocol>*)comparator interpretor:(BOOL (^)(NSComparisonResult inComparison))interpretor;

/** Set instance properties on the main thread. */
- (void)finishWithUpdate:(UCUpdate*)inUpdate error:(NSError*)inError completionHandler:(void(^)(UCUpdate*,NSError*))handler;
@end

@implementation UCUpdateDiscover

+ (NSString*)systemVersion {
	NSOperatingSystemVersion osv = [[NSProcessInfo new] operatingSystemVersion];
	return [NSString stringWithFormat:@"%01ld.%01ld.%01ld",osv.majorVersion,osv.minorVersion,osv.patchVersion];
}

+ (instancetype)discoverWithURL:(NSURL*)inDiscoveryURL revision:(NSString*)inRevision systemVersion:(NSString*)inSystemVersion queue:(NSOperationQueue*)inQueue completionHandler:(void(^)(UCUpdate*,NSError*))handler {
	return [(UCUpdateDiscover*)[[self class] alloc] initWithURL:inDiscoveryURL revision:inRevision systemVersion:inSystemVersion queue:inQueue completionHandler:handler];
}

- (instancetype)initWithURL:(NSURL*)inDiscoveryURL revision:(NSString*)inRevision systemVersion:(NSString*)inSystemVersion queue:(NSOperationQueue*)inQueue completionHandler:(void(^)(UCUpdate*,NSError*))handler {
	NSParameterAssert(inDiscoveryURL != nil);
	if ((self = [super init])) {
		self.discoveryURL = inDiscoveryURL;
		self.queue = inQueue;
		if (inQueue == nil) {
			self.queue = UpdateCore.sharedQueue;
		}
		self.progress = [NSProgress progressWithTotalUnitCount:100];
		[self.queue addOperationWithBlock:^{
			
			[self.progress becomeCurrentWithPendingUnitCount:80];
			
			// Fetch the URL
			NSError* fetchError = nil;
			NSData* discoveryData = [self dataWithContentsOfURL:self.discoveryURL error:&fetchError];
			if (fetchError != nil) {
				[self.progress resignCurrent];
				[self finishWithUpdate:nil error:fetchError completionHandler:handler];
				return;
			} else if (discoveryData == nil || discoveryData.length == 0) {
				[self.progress resignCurrent];
				[self finishWithUpdate:nil error:nil completionHandler:handler];
				return;
			}
			
			[self.progress resignCurrent];
			if (self.progress.isCancelled == YES) {
				[self finishWithUpdate:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil] completionHandler:handler];
				return;
			}
			[self.progress becomeCurrentWithPendingUnitCount:10];
			
			// Parse the discovery data into potential updates
			NSError* parseError = nil;
			UCIsolatedParseArrayEntries potentialUpdates = [self parseDiscoveryData:discoveryData error:&parseError];
			if (parseError != nil) {
				[self.progress resignCurrent];
				[self finishWithUpdate:nil error:parseError completionHandler:handler];
				return;
			} else if (potentialUpdates == nil || potentialUpdates.count == 0) {
				[self.progress resignCurrent];
				[self finishWithUpdate:nil error:nil completionHandler:handler];
				return;
			}
			
			[self.progress resignCurrent];
			if (self.progress.isCancelled == YES) {
				[self finishWithUpdate:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil] completionHandler:handler];
				return;
			}
			[self.progress becomeCurrentWithPendingUnitCount:10];
			
			// Evaluate potential updates
			NSError* evaluateError = nil;
			UCIsolatedParseEntry selectedEntry = [self evaluateEntries:potentialUpdates revision:inRevision systemVersion:inSystemVersion error:&evaluateError];
			if (evaluateError != nil) {
				[self.progress resignCurrent];
				[self finishWithUpdate:nil error:evaluateError completionHandler:handler];
				return;
			} else if (selectedEntry == nil) {
				// ...no entry selected; nothing to do
				[self.progress resignCurrent];
				[self finishWithUpdate:nil error:nil completionHandler:handler];
				return;
			}
			
			[self.progress resignCurrent];
			
			// Create a proposed update for the selected entry
			NSURL* downloadURL = [NSURL URLWithString:selectedEntry[UCIsolatedParseKeyDownloadURL]];
			if (downloadURL == nil || [downloadURL.absoluteString isEqualToString:@""]) {
				[self finishWithUpdate:nil error:[NSError errorWithDomain:NSPOSIXErrorDomain code:EFTYPE userInfo:nil] completionHandler:handler];
				return;
			}
			UCUpdate* update = [UCUpdate updateWithVersion:selectedEntry[UCIsolatedParseKeyRevision]
											 minimumSystem:selectedEntry[UCIsolatedParseKeyMinimumSystemVersion]
											   downloadURL:downloadURL];
			[self finishWithUpdate:update error:nil completionHandler:handler];
		}];
	}
	return self;
}

#pragma mark -

- (NSData*)dataWithContentsOfURL:(NSURL*)aURL error:(NSError**)outError {
	NSParameterAssert(aURL != nil);
	NSParameterAssert(outError != nil);

	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:aURL];
	request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
	
	UCIsolatedService* downloadService = [UCIsolatedService service:UCIsolatedServiceKeyDownload withProtocol:@protocol(UCIsolatedDownloadProtocol)];
	NSUUID* downloadIdentifier = [NSUUID new];
	
	// Track download at the byte level
	NSProgress* downloadProgress = [downloadService progressForIdentifier:downloadIdentifier];
	downloadProgress.kind = NSProgressKindFile;
	[downloadProgress setUserInfoObject:NSProgressFileOperationKindDownloading forKey:NSProgressFileOperationKindKey];
	[downloadProgress setUserInfoObject:aURL forKey:NSProgressFileURLKey];
	[downloadProgress setUserInfoObject:@(0) forKey:NSProgressFileCompletedCountKey];
	[downloadProgress setUserInfoObject:@(1) forKey:NSProgressFileTotalCountKey];
	
	__block NSData* data = nil;
	__block NSError* downloadError = nil;
	[[downloadService syncWithErrorHandler:^(NSError* inServiceError) {
		downloadError = inServiceError;
	}] dataWithContentsOfRequest:request identifier:downloadIdentifier withReply:^(NSData* inData, NSError* inDownloadError) {
		data = inData;
		downloadError = inDownloadError;
	}];
	
	if (outError != nil) {
		*outError = downloadError;
	}
	
	return data;
}

- (UCIsolatedParseArrayEntries)parseDiscoveryData:(NSData*)someData error:(NSError**)outError {
	NSParameterAssert(someData != nil);
	NSParameterAssert(outError != nil);
	
	UCIsolatedService* parseService = [UCIsolatedService service:UCIsolatedServiceKeyParse withProtocol:@protocol(UCIsolatedParseProtocol)];
	__block UCIsolatedParseArrayEntries entries = nil;
	__block NSError* parseError = nil;
	[[parseService syncWithErrorHandler:^(NSError* inServiceError) {
		parseError = inServiceError;
	}] parseData:someData withReply:^(UCIsolatedParseArrayEntries inEntries, NSError* inParseError) {
		entries = inEntries;
		parseError = inParseError;
	}];

	if (parseError != nil) {
		if (outError != nil) {
			*outError = parseError;
		}
		return nil;
	}
	
	return entries;
}

- (UCIsolatedParseEntry)evaluateEntries:(UCIsolatedParseArrayEntries)someEntries revision:(NSString*)inRevision systemVersion:(NSString*)inSystemVersion error:(NSError**)outError {
	UCVersionComparison* vc = [UCVersionComparison new];
	
	// Filter entries by version, then minimum supported operating system
	UCIsolatedParseArrayEntries applicableEntries = [self filterEntries:someEntries forKey:UCIsolatedParseKeyRevision withValue:inRevision comparator:vc interpretor:^BOOL(NSComparisonResult inComparison) {
		return (inComparison == NSOrderedAscending);
	}];
	applicableEntries = [self filterEntries:applicableEntries forKey:UCIsolatedParseKeyMinimumSystemVersion withValue:inSystemVersion comparator:vc interpretor:^BOOL(NSComparisonResult inComparison) {
		return ((inComparison == NSOrderedSame) || (inComparison == NSOrderedDescending));
	}];
	
	// Sort the items by version, then minimum supported operating system
	NSSortDescriptor* versionSort = [NSSortDescriptor sortDescriptorWithKey:UCIsolatedParseKeyRevision ascending:NO comparator:^NSComparisonResult(id inLHS,id inRHS) {
		return [vc compareVersion:inLHS toVersion:inRHS];
	}];
	NSSortDescriptor* systemSort = [NSSortDescriptor sortDescriptorWithKey:UCIsolatedParseKeyMinimumSystemVersion ascending:NO comparator:^NSComparisonResult(id inLHS,id inRHS) {
		return [vc compareVersion:inLHS toVersion:inRHS];
	}];
	applicableEntries = [applicableEntries sortedArrayUsingDescriptors:@[versionSort,systemSort]];
	
	return applicableEntries.firstObject;
}

- (UCIsolatedParseArrayEntries)filterEntries:(UCIsolatedParseArrayEntries)someEntries forKey:(NSString*)inKey withValue:(NSString*)inValue comparator:(NSObject<UCVersionComparisonProtocol>*)comparator interpretor:(BOOL (^)(NSComparisonResult inComparison))interpretor {
	NSParameterAssert(comparator != nil);
	NSParameterAssert(interpretor != nil);
	NSIndexSet* passingIndexes = [someEntries indexesOfObjectsPassingTest:^BOOL(UCIsolatedParseEntry inEntry,NSUInteger __unused inIndex,BOOL* __unused outShouldStop) {
		BOOL pass = NO;
		NSString* value = inEntry[inKey];
		if (value != nil) {
			NSComparisonResult order = [comparator compareVersion:inValue toVersion:value];
			pass = interpretor(order);
		}
		return pass;
	}];
	return [someEntries objectsAtIndexes:passingIndexes];
}

#pragma mark -

- (void)finishWithUpdate:(UCUpdate*)inUpdate error:(NSError*)inError completionHandler:(void(^)(UCUpdate*,NSError*))handler {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.error = inError;
		self.available = inUpdate;
		self.isFinished = YES;
		if (handler != nil) {
			handler(inUpdate, inError);
		}
	});
}

@end

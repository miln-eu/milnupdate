//
//  UCUpdateDownload.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCUpdateDownload.h"
#import "UCIsolatedService.h"
#import "UCIsolatedDownloadProtocol.h"
#import "UCIsolatedVerifyProtocol.h"
#import "UpdateCorePrivate.h"

NSString* UCUpdateDownloadKeyLocalizedProgress = @"localizedProgress";

static NSString* UCUpdateDownloadKVOContextProgress = @"UCUpdateDownloadKVOContextProgress";

static NSString* UCUpdateDownloadLocalizedPreparing = @"download.preparing";
static NSString* UCUpdateDownloadLocalizedVerifying = @"download.verifying";
static NSString* UCUpdateDownloadLocalizedDone = @"download.done";

static NSString* UCUpdateDownloadPrivateCacheFoldername = @"UpdateCore";

@interface UCUpdateDownload ()
@property(assign,readwrite) BOOL isFinished;
@property(strong,readwrite) NSError* error;
@property(strong,readwrite) NSURL* fileURL;
@property(strong,readwrite) NSString* localizedProgress;
@property(strong,readwrite) NSString* commonName;
// ...
@property(strong) NSOperationQueue* queue;
@property(strong) NSProgress* progress;

- (NSURL*)fileWithContentsOfRequest:(NSURLRequest*)inRequest error:(NSError**)outError;
- (NSString*)verifiedOriginatorOfPackageAtURL:(NSURL*)inPackageURL error:(NSError**)outError;
- (void)finishWithFile:(NSURL*)inFileURL commonName:(NSString*)inCommonName error:(NSError*)inError completionHandler:(void(^)(NSURL*,NSString*,NSError*))inHandler;

/** Update progress string on main thread; eases KVO in user interface */
- (void)updateProgress:(NSString*)inProgress localise:(BOOL)needsLocalisation;
@end

@implementation UCUpdateDownload

+ (instancetype)downloadWithRequest:(NSURLRequest*)inRequest queue:(NSOperationQueue*)inQueue completionHandler:(void(^)(NSURL*,NSString*,NSError*))inHandler {
	return [(UCUpdateDownload*)[[self class] alloc] initWithRequest:inRequest queue:inQueue completionHandler:inHandler];
}

- (instancetype)initWithRequest:(NSURLRequest*)inRequest queue:(NSOperationQueue* __nullable)inQueue completionHandler:(void(^ __nullable)(NSURL* __nullable,NSString* __nullable, NSError* __nullable))inHandler {
	NSParameterAssert(inRequest != nil);
	if ((self = [super init])) {
		self.queue = inQueue;
		if (inQueue == nil) {
			self.queue = UpdateCore.sharedQueue;
		}
		
		self.progress = [NSProgress progressWithTotalUnitCount:100];
		self.progress.kind = NSProgressKindFile;
		[self.progress setUserInfoObject:NSProgressFileOperationKindReceiving forKey:NSProgressFileOperationKindKey];
		[self.progress setUserInfoObject:inRequest.URL forKey:NSProgressFileURLKey];
		[self.progress setUserInfoObject:@(0) forKey:NSProgressFileCompletedCountKey];
		[self.progress setUserInfoObject:@(1) forKey:NSProgressFileTotalCountKey];
		
		[self updateProgress:UCUpdateDownloadLocalizedPreparing localise:YES];
		
		[self.queue addOperationWithBlock:^{
			
			[self.progress becomeCurrentWithPendingUnitCount:90];
			
			// Download the request to a file
			NSError* downloadError = nil;
			NSURL* downloadedFile = [self fileWithContentsOfRequest:inRequest error:&downloadError];
			if (downloadError != nil) {
				[self.progress resignCurrent];
				[self finishWithFile:nil commonName:nil error:downloadError completionHandler:inHandler];
				return;
			}
			
			[self.progress resignCurrent];
			[self.progress setUserInfoObject:NSProgressFileOperationKindDecompressingAfterDownloading forKey:NSProgressFileOperationKindKey];
			[self.progress becomeCurrentWithPendingUnitCount:10];
			
			[self updateProgress:UCUpdateDownloadLocalizedVerifying localise:YES];
			
			NSError* verifyError = nil;
			NSString* cn = [self verifiedOriginatorOfPackageAtURL:downloadedFile error:&verifyError];
			if (verifyError != nil) {
				[self finishWithFile:nil commonName:nil error:verifyError completionHandler:inHandler];
				
				// Remove invalid downloaded file
				NSError* removeError = nil;
				(void) [[NSFileManager new] removeItemAtURL:downloadedFile error:&removeError];
				if (removeError != nil) {
					NSLog(@"[updatecore] Error removing invalid update <%@>: %@", downloadedFile, removeError);
				}
				[self.progress resignCurrent];
				return;
			}
			
			[self.progress resignCurrent];
			
			[self finishWithFile:downloadedFile commonName:cn error:nil completionHandler:inHandler];

			[self updateProgress:UCUpdateDownloadLocalizedDone localise:YES];
		}];
	}
	return self;
}

- (void)cancel {
	// Use NSProgress to propogate cancellation
	[self.progress cancel];
}

+ (void)clearCache {
	// Clear cache from previous sessions
	NSFileManager* fm = [NSFileManager new];
	NSURL* cacheDirectoryURL = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
	cacheDirectoryURL = [cacheDirectoryURL URLByAppendingPathComponent:UCUpdateDownloadPrivateCacheFoldername isDirectory:YES];
	if (cacheDirectoryURL != nil) {
		(void) [fm removeItemAtURL:cacheDirectoryURL error:nil];
	}
}

- (NSURL*)fileWithContentsOfRequest:(NSURLRequest*)inRequest error:(NSError**)outError {
	NSParameterAssert(inRequest != nil);
	NSParameterAssert(outError != nil);
	
	UCIsolatedService* downloadService = [UCIsolatedService service:UCIsolatedServiceKeyDownload withProtocol:@protocol(UCIsolatedDownloadProtocol)];
	NSUUID* downloadIdentifier = [NSUUID new];
	
	// Track download progress
	NSProgress* downloadProgress = [downloadService progressForIdentifier:downloadIdentifier];
	downloadProgress.kind = NSProgressKindFile;
	[downloadProgress setUserInfoObject:NSProgressFileOperationKindDownloading forKey:NSProgressFileOperationKindKey];
	[downloadProgress setUserInfoObject:inRequest.URL forKey:NSProgressFileURLKey];
	[downloadProgress setUserInfoObject:@(0) forKey:NSProgressFileCompletedCountKey];
	[downloadProgress setUserInfoObject:@(1) forKey:NSProgressFileTotalCountKey];
	// ...observe byte level progress tracking and propogate to instance property (binding is not available in Foundation)
	NSArray<NSString*>* observedProgressKeys = @[NSStringFromSelector(@selector(localizedAdditionalDescription))];
	for(NSString* keyPath in observedProgressKeys) {
		[downloadProgress addObserver:self forKeyPath:keyPath options:0 context:(__bridge void * _Nullable)(UCUpdateDownloadKVOContextProgress)];
	}
	
	// Support cancelling while downloading
	__block NSError* downloadError = nil;
	downloadProgress.pausable = NO;
	downloadProgress.cancellable = YES;
	downloadProgress.cancellationHandler = ^(){
		[[downloadService syncWithErrorHandler:^(NSError* inServiceError){
			downloadError = inServiceError;
		}] cancelDownloadWithIdentifier:downloadIdentifier];
	};
	
	__block NSURL* fileURL = nil;
	[[downloadService syncWithErrorHandler:^(NSError* inServiceError) {
		downloadError = inServiceError;
	}] fileWithContentsOfRequest:inRequest identifier:downloadIdentifier withReply:^(NSData* inBookmark, NSString* inSuggestedFilename, NSError* inDownloadError) {
		downloadError = inDownloadError;
		if (inBookmark != nil && inDownloadError == nil) {
			NSError* bookmarkError = nil;
			NSURL* tmpURL = [NSURL URLByResolvingBookmarkData:inBookmark options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:nil error:&bookmarkError];
			
			// Downloaded file will be removed when this handler finishes; open or move the file
			NSFileManager* fm = [NSFileManager new];
			
			// Prepare a URL to move the downloaded file to
			NSError* urlError = nil;
			NSURL* cacheDirectoryURL = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:tmpURL create:YES error:&urlError];
			if (cacheDirectoryURL == nil || urlError != nil) {
				downloadError = urlError;
				return;
			}
			
			// ...append unique folder to reduce chance of overwriting an existing file or folder
			cacheDirectoryURL = [cacheDirectoryURL URLByAppendingPathComponent:UCUpdateDownloadPrivateCacheFoldername isDirectory:YES];
			cacheDirectoryURL = [cacheDirectoryURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString] isDirectory:YES];
			NSError* createError = nil;
			BOOL validCreate = [fm createDirectoryAtURL:cacheDirectoryURL withIntermediateDirectories:YES attributes:nil error:&createError];
			if (validCreate == NO || createError != nil) {
				downloadError = createError;
				return;
			}
			
			// ...move and rename the downloaded assumed package file
			NSString* filename = inSuggestedFilename;
			if (filename == nil) {
				filename = [tmpURL.lastPathComponent stringByAppendingPathExtension:@"pkg"];
			}
			NSURL* destinationURL = [cacheDirectoryURL URLByAppendingPathComponent:filename isDirectory:NO];
			NSError* moveError = nil;
			BOOL validMove = [fm moveItemAtURL:tmpURL toURL:destinationURL error:&moveError];
			if (validMove == NO || moveError != nil) {
				downloadError = moveError;
				return;
			}
			
			fileURL = destinationURL;
			downloadError = bookmarkError;
		}
	}];

	// Stop observing progress
	for(NSString* keyPath in observedProgressKeys) {
		[downloadProgress removeObserver:self forKeyPath:keyPath context:(__bridge void * _Nullable)(UCUpdateDownloadKVOContextProgress)];
	}
	
	if (outError != nil) {
		*outError = downloadError;
	}
	
	return fileURL;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (context == (__bridge void * _Nullable)(UCUpdateDownloadKVOContextProgress)) {
		if ([object isKindOfClass:NSProgress.class] == YES) {
			NSProgress* downloadProgress = object;
			[self updateProgress:downloadProgress.localizedAdditionalDescription localise:NO];
		}
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (NSString*)verifiedOriginatorOfPackageAtURL:(NSURL*)inPackageURL error:(NSError**)outError {
	NSParameterAssert(inPackageURL != nil);
	NSParameterAssert(outError != nil);
	
	UCIsolatedService* verifyService = [UCIsolatedService service:UCIsolatedServiceKeyVerify withProtocol:@protocol(UCIsolatedVerifyProtocol)];
	__block NSString* originator = nil;
	__block NSError* verifyError = nil;
	[[verifyService syncWithErrorHandler:^(NSError* inServiceError) {
		verifyError = inServiceError;
	}] verifyPackageAtURL:inPackageURL withReply:^(NSString* inOriginator, NSError* inVerifyError) {
		originator = inOriginator;
		verifyError = inVerifyError;
	}];
	
	if (outError != nil) {
		*outError = verifyError;
	}
	
	return originator;
}

- (void)finishWithFile:(NSURL*)inFileURL commonName:(NSString*)inCommonName error:(NSError*)inError completionHandler:(void(^)(NSURL*,NSString*,NSError*))inHandler {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.error = inError;
		self.fileURL = inFileURL;
		self.commonName = inCommonName;
		self.isFinished = YES;
		if (inHandler != nil) {
			inHandler(inFileURL, inCommonName, inError);
		}
	});
}

- (void)updateProgress:(NSString*)inLocalisedProgress localise:(BOOL)needsLocalisation {
	if (needsLocalisation == YES) {
		NSBundle* thisBundle = [NSBundle bundleForClass:self.class];
		NSString* thisClass = NSStringFromClass(self.class);
		inLocalisedProgress = [thisBundle localizedStringForKey:inLocalisedProgress value:inLocalisedProgress table:thisClass];
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		self.localizedProgress = inLocalisedProgress;
	});
}

@end

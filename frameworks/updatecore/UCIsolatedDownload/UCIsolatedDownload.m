//
//  UCIsolatedDownload.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCIsolatedDownload.h"
#import "UCIsolatedServiceProtocol.h"

static NSString* UCIsolatedDownloadKVOContextSession = @"UCIsolatedDownloadKVOContextSession";

static NSString* NSURLSessionKeyCountOfBytesReceived = @"countOfBytesReceived"; /* number of body bytes already received */
static NSString* NSURLSessionKeyCountOfBytesExpectedToReceive = @"countOfBytesExpectedToReceive"; /* number of byte bytes we expect to receive, usually derived from the Content-Length header of an HTTP response. */

@interface UCIsolatedDownload ()
@property(strong) NSMutableDictionary<NSUUID*,NSURLSessionTask*>* tasks; /**< Ongoing tasks. */

/** Remote proxy object implementing service protocol. Used to provide progress updates. */
- (NSObject<UCIsolatedServiceProtocol>*)client;

/** Add a task, observe progress, and inform client. */
- (void)addTask:(NSURLSessionTask*)aTask withIdentifier:(NSUUID*)anIdentifier;

/** Update client about task's progress. */
- (void)updateProgressForTask:(NSURLSessionTask*)aTask;

/** Remove a completed task, stop observing, and inform client. */
- (void)removeTaskWithIdentifier:(NSUUID*)anIdentifier;

/** Return the identifier for an ongoing task. */
- (NSUUID*)identifierForTask:(NSURLSessionTask*)aTask;

/** Return an error if the response represents a protocol level error. */
- (NSError*)protocolErrorForResponse:(NSURLResponse*)inResponse;
@end

@implementation UCIsolatedDownload

- (instancetype)init {
	if ((self = [super init])) {
		self.tasks = [NSMutableDictionary new];
	}
	return self;
}

- (NSArray<NSString*>*)sessionKeyPathsAffectingProgress {
	return @[NSURLSessionKeyCountOfBytesReceived, NSURLSessionKeyCountOfBytesExpectedToReceive];
}

- (void)dataWithContentsOfRequest:(NSURLRequest*)aRequest identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSData*, NSError*))reply {
	NSURLSessionDataTask* task = [NSURLSession.sharedSession dataTaskWithRequest:aRequest completionHandler:^(NSData* inData, NSURLResponse* __unused inResponse, NSError* inError) {
		[self removeTaskWithIdentifier:anIdentifier];
        
        NSError* taskError = inError;
        if (taskError == nil) {
            taskError = [self protocolErrorForResponse:inResponse];
        }
        
		reply(inData, taskError);
	}];
	[self addTask:task withIdentifier:anIdentifier];
	[task resume];
}

- (void)fileWithContentsOfRequest:(NSURLRequest*)aRequest identifier:(NSUUID*)anIdentifier withReply:(void (^)(NSData*, NSString*, NSError*))reply {
	NSURLSessionDownloadTask* task = [NSURLSession.sharedSession downloadTaskWithRequest:aRequest completionHandler:^(NSURL* inFileLocation, NSURLResponse* inResponse, NSError* inError) {
		[self removeTaskWithIdentifier:anIdentifier];
		
		NSError* taskError = nil;
		NSURL* downloadedFile = nil;
		
		if (inError != nil) {
			taskError = inError;
        } else {
            taskError = [self protocolErrorForResponse:inResponse];
        }
        
        // No error has been detected, presume response is valid
        if (taskError == nil) {
			// Downloaded file will be removed when this handler finishes; open or move the file
			NSFileManager* fm = [NSFileManager new];
			
			// Prepare a URL to move the downloaded file to
			NSError* cacheError = nil;
			NSURL* cacheDirectoryURL = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:inFileLocation create:YES error:&cacheError];
			if (cacheDirectoryURL == nil || cacheError != nil) {
				taskError = cacheError;
			} else {
				NSError* createError = nil;
				BOOL validCreate = [fm createDirectoryAtURL:cacheDirectoryURL withIntermediateDirectories:YES attributes:nil error:&createError];
				if (validCreate == NO || createError != nil) {
					taskError = createError;
				} else {
					// ...move the downloaded file, using a uuid name to avoid trusting the server's suggestion
					NSURL* destinationURL = [cacheDirectoryURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString] isDirectory:NO];
					NSError* moveError = nil;
					BOOL validMove = [fm moveItemAtURL:inFileLocation toURL:destinationURL error:&moveError];
					taskError = moveError;
					
					if (validMove == YES) {
						downloadedFile = destinationURL;
					}
				}
			}
		}
		
		if (taskError != nil) {
			// Error while fetching request
			reply(nil, nil, taskError);
			return;
		}
		
		// Convert URL into bookmark for passing across process boundaries
		NSError* bookmarkError = nil;
		NSData* bookmark = [downloadedFile bookmarkDataWithOptions:NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&bookmarkError];
		if (bookmarkError != nil) {
			reply(nil, nil, bookmarkError);
			return;
		}
		
		reply(bookmark, inResponse.suggestedFilename, nil);
	}];
	[self addTask:task withIdentifier:anIdentifier];
	[task resume];
}

- (void)cancelDownloadWithIdentifier:(NSUUID*)anIdentifier {
	[self.tasks[anIdentifier] cancel];
}

- (void)cancelAll {
	for(NSURLSessionTask* task in self.tasks.allValues) {
		[task cancel];
	}
}

#pragma mark -

- (NSObject<UCIsolatedServiceProtocol>*)client {
	return (NSObject<UCIsolatedServiceProtocol>*)[self.xpcConnection remoteObjectProxy];
}

- (void)addTask:(NSURLSessionTask*)aTask withIdentifier:(NSUUID*)anIdentifier {
	NSParameterAssert(aTask != nil);
	NSParameterAssert(anIdentifier != nil);
	NSParameterAssert(self.tasks[anIdentifier] == nil);
	
	self.tasks[anIdentifier] = aTask;
	[self.client serviceDidBeginTaskWithIdentifier:anIdentifier];
	
	for(NSString* sessionKeyPath in self.sessionKeyPathsAffectingProgress) {
		[aTask addObserver:self forKeyPath:sessionKeyPath options:NSKeyValueObservingOptionInitial context:(__bridge void * _Nullable)(UCIsolatedDownloadKVOContextSession)];
	}
}

- (void)updateProgressForTask:(NSURLSessionTask*)aTask {
	NSParameterAssert(aTask != nil);
	
	NSUUID* identifier = [self identifierForTask:aTask];
	if (identifier != nil) {
		[self.client serviceDidUpdateTaskWithIdentifier:identifier completing:aTask.countOfBytesReceived ofTotalUnits:aTask.countOfBytesExpectedToReceive];
	}
}

- (void)removeTaskWithIdentifier:(NSUUID*)anIdentifier {
	NSParameterAssert(anIdentifier != nil);
	
	NSURLSessionTask* task = self.tasks[anIdentifier];
	if (task != nil) {
		for(NSString* sessionKeyPath in self.sessionKeyPathsAffectingProgress) {
			[task removeObserver:self forKeyPath:sessionKeyPath context:(__bridge void * _Nullable)(UCIsolatedDownloadKVOContextSession)];
		}
		[self.tasks removeObjectForKey:anIdentifier];
	}
	[self.client serviceDidEndTaskWithIdentifier:anIdentifier];
}

- (NSUUID*)identifierForTask:(NSURLSessionTask*)aTask {
	__block NSUUID* identifier = nil;
	[self.tasks enumerateKeysAndObjectsUsingBlock:^(NSUUID* inIdentifier, NSURLSessionTask* inTask, BOOL* outShouldStop) {
		if ([aTask isEqualTo:inTask] == YES) {
			identifier = inIdentifier;
			if (outShouldStop != nil) {
				*outShouldStop = YES;
			}
		}
	}];
	return identifier;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
	if (context == (__bridge void * _Nullable)(UCIsolatedDownloadKVOContextSession)) {
		[self updateProgressForTask:object];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (NSError*)protocolErrorForResponse:(NSURLResponse*)inResponse {
    NSError* protocolError = nil;
    
    // Special case error detection for the HTTP protocol
    if ([inResponse isKindOfClass:NSHTTPURLResponse.class]) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)inResponse;
        // HTTP status must be between 200 - 299 for the response to be accepted
        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 299) {
            NSString* errorDescription = [NSString stringWithFormat:@"%@ (%@)",[NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode],httpResponse.URL.absoluteString];
            protocolError = [NSError errorWithDomain:NSStringFromClass(self.class) code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey:errorDescription}];
        }
    }
    
    return protocolError;
}

@end

//
//  UCAuthorization.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCAuthorization.h"

@interface UCAuthorization ()
@property(assign,readwrite) AuthorizationRef authorization;
@end

@implementation UCAuthorization

+ (instancetype)authorizationWithRights:(NSArray<NSString*>*)someRights prompt:(NSString*)inOptionalPrompt error:(NSError**)outError {
	return [(UCAuthorization*)[[self class] alloc] initWithRights:someRights prompt:inOptionalPrompt error:outError];
}

- (instancetype)initWithRights:(NSArray<NSString *> *)someRights prompt:(NSString*)inOptionalPrompt error:(NSError**)outError {
	NSParameterAssert(someRights.count > 0);
	NSParameterAssert(outError != nil);

	AuthorizationRef auth = NULL;
		
	// Prepare block of authorization rights
	size_t authItemsSize = (sizeof(AuthorizationItem) * someRights.count);
	NSData* block = [NSMutableData dataWithLength:authItemsSize];
	AuthorizationItem* authItems = (AuthorizationItem*) block.bytes;
	CFIndex rightIndex = 0;
	for (NSString* right in someRights) {
		authItems[rightIndex].name = right.UTF8String;
		++rightIndex;
	}
	
	AuthorizationRights authRights;
	memset(&authRights,0,sizeof(authRights));
	authRights.count = (UInt32) someRights.count;
	authRights.items = authItems;
	
	AuthorizationFlags flags = kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
	
	AuthorizationEnvironment authEnvironment;
	memset(&authEnvironment,0,sizeof(authEnvironment));
	AuthorizationItem authPrompt;
	memset(&authPrompt,0,sizeof(authPrompt));
	authEnvironment.items = &authPrompt;
	if (inOptionalPrompt != nil) {
		authEnvironment.count = 1;
		authPrompt.name = kAuthorizationEnvironmentPrompt;
		authPrompt.valueLength = inOptionalPrompt.length;
		authPrompt.value = (char*) inOptionalPrompt.UTF8String;
	}
	
	OSStatus authCreateError = AuthorizationCreate(&authRights,&authEnvironment,flags,&auth);
	if (authCreateError != errAuthorizationSuccess) {
		if (outError != nil) {
			*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:authCreateError userInfo:nil];
		}
		return nil;
	}
	
	if ((self = [super init])) {
		self.authorization = auth;
	}
	return self;
}

- (void)dealloc {
	if (self.authorization != nil) {
		(void) AuthorizationFree(self.authorization, kAuthorizationFlagDefaults);
		self.authorization = nil;
	}
}

@end

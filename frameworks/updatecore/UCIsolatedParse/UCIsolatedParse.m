//
//  UCIsolatedParse.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCIsolatedParse.h"

static NSString* UCIsolatedParseRootElementRSS = @"rss";
static NSString* UCIsolatedXPathEnclosures = @"/rss/channel/item[enclosure]";
// ...
static NSString* UCIsolatedXPathEnclosureDownloadURL = @"string(enclosure/@url)";
// version and minimumSystemVersion are extensions of RSS; ignore the namespace in XPath query
static NSString* UCIsolatedXPathEnclosureRevision = @"string(enclosure/@*[local-name()='version'])";
static NSString* UCIsolatedXPathEnclosureMinimumSystemVersion = @"string(*:minimumSystemVersion)";

@interface UCIsolatedParse ()
- (NSString*)stringFromNode:(NSXMLNode*)aNode forXQuery:(NSString*)anXQuery error:(NSError**)outError;
@end

@implementation UCIsolatedParse

- (void)parseData:(NSData*)someData withReply:(void (^)(UCIsolatedParseArrayEntries, NSError*))reply {
	// Require the feed to be a valid well-formed XML document
	NSError* xmlError = nil;
	NSXMLDocument* xmlFeed = [[NSXMLDocument alloc] initWithData:someData options:NSXMLNodeOptionsNone error:&xmlError];
	if (xmlError != nil) {
		reply(nil, xmlError);
		return;
	}
	if (xmlFeed == nil) {
		reply(@[], nil);
		return;
	}
	
	// Ensure document is an RSS feed
	if ([[xmlFeed.rootElement.name lowercaseString] isEqualToString:UCIsolatedParseRootElementRSS] == NO) {
		reply(nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:EFTYPE userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Feed root must be <%@>",UCIsolatedParseRootElementRSS]}]);
		return;
	}
	
	// Extract enclosures
	NSError* enclosuresError = nil;
	NSArray<NSXMLNode*>* enclosures = [xmlFeed nodesForXPath:UCIsolatedXPathEnclosures error:&enclosuresError];
	if (enclosuresError != nil) {
		reply(nil, enclosuresError);
		return;
	}
	if (enclosures == nil) {
		reply(@[], nil);
		return;
	}
	NSMutableArray<UCIsolatedParseEntry>* entries = [NSMutableArray new];
	// Extract version related attributes and values from the item
	NSDictionary<UCIsolatedParseKey,NSString*>* extractionXPaths = @{UCIsolatedParseKeyDownloadURL: UCIsolatedXPathEnclosureDownloadURL,
																	 UCIsolatedParseKeyRevision: UCIsolatedXPathEnclosureRevision,
																	 UCIsolatedParseKeyMinimumSystemVersion: UCIsolatedXPathEnclosureMinimumSystemVersion};
	for(NSXMLNode* enclosure in enclosures) {
		NSMutableDictionary<UCIsolatedParseKey,NSString*>* entry = [NSMutableDictionary new];
		for(NSString* entryKey in extractionXPaths) {
			NSString* query = extractionXPaths[entryKey];
			
			NSError* queryError = nil;
			NSString* entryValue = [self stringFromNode:enclosure forXQuery:query error:&queryError];
			// Any error and the feed fails
			if (queryError != nil) {
				reply(nil, queryError);
				return;
			}
			if (entryValue != nil) {
				entry[entryKey] = entryValue;
			}
		}
		// Discard entries with missing values
		if (entry.count == extractionXPaths.count) {
			[entries addObject:entry];
		}
	}
	
	reply(entries, nil);
}

- (NSString*)stringFromNode:(NSXMLNode*)aNode forXQuery:(NSString*)anXQuery error:(NSError**)outError {
	NSString* result = nil;
	NSError* queryError = nil;
	NSArray* queryResult = [aNode objectsForXQuery:anXQuery error:&queryError];
	if ((queryResult.count == 1) && (queryError == nil)) {
		id firstResult = [queryResult firstObject];
		if ([firstResult isKindOfClass:NSString.class]) {
			// Trim whitespace and ensure result is not empty string
			result = [(NSString*)firstResult stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
			if ([result isEqualToString:@""] == YES) {
				result = nil;
			}
		}
	}
	
	// Lack of a string indicates an error
	if (result == nil) {
		queryError = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid result for '%@': %@",anXQuery,queryResult]}];
	}
	
	if (outError != nil) {
		*outError = queryError;
	}
	
	return result;
}


@end

//
//  UCVersionComparison.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

#import "UCVersionComparison.h"

@interface UCVersionComparison ()
- (NSComparisonResult)compareComponent:(NSString*)inLHS toComponent:(NSString*)inRHS;
- (NSArray<NSString*>*)versionComponentsFromString:(NSString *)aVersion;
@end

@implementation UCVersionComparison

- (BOOL)isUnstableVersion:(NSString*)inVersion {
	if (inVersion == nil) {
		return NO;
	}
	return ([inVersion rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound);
}

- (NSComparisonResult)compareVersion:(NSString*)inLHS toVersion:(NSString*)inRHS {
	if ((inLHS == nil) && (inRHS == nil)) {
		return NSOrderedSame;
	} else if ([inLHS isEqualToString:inRHS]) {
		return NSOrderedSame;
	} else if ((inLHS != nil) && (inRHS == nil)) {
		return NSOrderedDescending;
	} else if ((inLHS == nil) && (inRHS != nil)) {
		return NSOrderedAscending;
	}
	
	if (self.allowUnstable == NO) {
		BOOL lhsUnstable = [self isUnstableVersion:inLHS];
		BOOL rhsUnstable = [self isUnstableVersion:inRHS];
		
		if (lhsUnstable && !rhsUnstable) {
			return NSOrderedAscending;
		} else if (!lhsUnstable && rhsUnstable) {
			return NSOrderedDescending;
		}
	}
	
	NSComparisonResult result = NSOrderedSame;
	
	NSArray<NSString*>* lhsComponents = [self versionComponentsFromString:inLHS];
	NSArray<NSString*>* rhsComponents = [self versionComponentsFromString:inRHS];
	
	NSInteger i = 0;
	while((result == NSOrderedSame) && ((i < lhsComponents.count) || (i < rhsComponents.count))) {
		NSString* lhsComponent = (i < lhsComponents.count ? lhsComponents[i] : nil);
		NSString* rhsComponent = (i < rhsComponents.count ? rhsComponents[i] : nil);
		
		result = [self compareComponent:lhsComponent toComponent:rhsComponent];
		
		i++;
	}
	
	return result;
}

- (NSComparisonResult)compareComponent:(NSString*)inLHS toComponent:(NSString*)inRHS {
	if ((inLHS != nil) && (inRHS == nil)) {
		return (([inLHS rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound) ? NSOrderedDescending : NSOrderedAscending);
	} else if ((inLHS == nil) && (inRHS != nil)) {
		return (([inRHS rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound) ? NSOrderedAscending : NSOrderedDescending);
	} else if ([inLHS isEqualToString:inRHS]) {
		return NSOrderedSame;
	} else {
		BOOL lhsAlphaOnly = ([inLHS rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound);
		BOOL rhsAlphaOnly = ([inRHS rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location != NSNotFound);
		
		if ((lhsAlphaOnly == YES) && (rhsAlphaOnly == NO)) {
			return NSOrderedDescending;
		} else if ((lhsAlphaOnly == NO) && (rhsAlphaOnly == YES)) {
			return NSOrderedAscending;
		}
	}
	
	return [inLHS compare:inRHS options:NSNumericSearch];
}

- (NSArray<NSString*>*)versionComponentsFromString:(NSString *)aVersion {
	// Simple division of version by decimal points (.)
	NSArray<NSString*>* pointComponents = [aVersion componentsSeparatedByString:@"."];
	
	NSCharacterSet* setOfNonDecimalDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
	
	NSMutableArray<NSString*>* components = [NSMutableArray new];
	[pointComponents enumerateObjectsUsingBlock:^(NSString* inComponent,NSUInteger __unused inIndex,BOOL* __unused outShouldStop) {
		NSString* component = [[inComponent stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
		
		// Does this component contain anything more than digits?
		NSRange found = [component rangeOfCharacterFromSet:setOfNonDecimalDigits];
		if (found.location == NSNotFound) {
			// Fix for missing values before periods, .1
			if ([component isEqualToString:@""]) {
				component = @"0";
			}
			
			// Component is a plain number
			[components addObject:component];
		} else {
			// Component contains something other than decimal digits
			NSScanner* scanner = [NSScanner scannerWithString:component];
			scanner.charactersToBeSkipped = NSCharacterSet.whitespaceAndNewlineCharacterSet;
			
			NSString* digits = nil;
			NSString* alpha = nil;
			
			NSCharacterSet* digitsSet = NSCharacterSet.decimalDigitCharacterSet;
			NSCharacterSet* nonDigitsSet = digitsSet.invertedSet;
			
			while([scanner isAtEnd] == NO &&
				  ([scanner scanCharactersFromSet:digitsSet intoString:&digits] ||
				   [scanner scanCharactersFromSet:nonDigitsSet intoString:&alpha])) {
				if (digits != nil) {
					[components addObject:[[digits stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString]];
					digits = nil;
				}
				
				if (alpha != nil) {
					alpha = [[alpha stringByTrimmingCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet] lowercaseString];
					
					// Fix for punctuation separations such as brackets and hypens between digits, 1.0 (1234)
					if ([alpha isEqualToString:@""] == YES) {
						alpha = @"0";
					}
					[components addObject:alpha];
					alpha = nil;
				}
			}
		}
	}];
	
	return components;
}

@end

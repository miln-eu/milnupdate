//
//  versionComparisonTests.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence
//
//  Includes BSD licensed work from:
//     Copyright (c) 2006-2013 Andy Matuschak.
//     Copyright (c) 2009-2013 Elgato Systems GmbH.
//     Copyright (c) 2011-2014 Kornel Lesiński.
//     Copyright (c) 2015-2017 Mayur Pawashe.
//     Copyright (c) 2014 C.W. Betts.
//     Copyright (c) 2014 Petroules Corporation.
//     Copyright (c) 2014 Big Nerd Ranch.
//     All rights reserved.
//

@import XCTest;
#import "UCVersionComparison.h"

@interface versionComparisonTests : XCTestCase
@end

@implementation versionComparisonTests

#define UCAssertOrder(comparator, a, b, c) XCTAssertTrue([comparator compareVersion:a toVersion:b] == c, @"b should be newer than a!")
#define UCAssertAscending(comparator, a, b) UCAssertOrder(comparator, a, b, NSOrderedAscending)
#define UCAssertDescending(comparator, a, b) UCAssertOrder(comparator, a, b, NSOrderedDescending)
#define UCAssertEqual(comparator, a, b) UCAssertOrder(comparator, a, b, NSOrderedSame)

- (void)testAlphaVersusNil
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	UCAssertAscending(comparator, @"1.0b1", @"1.0");
}

- (void)testPostAlphaDigitVersusNil
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	UCAssertAscending(comparator, @"1.0b", @"1.0b2");
}

- (void)testPostAlphaVersusDigit
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	UCAssertAscending(comparator, @"1.0b1 (1234)", @"1.0 (1234)");
}

- (void)testPostAlphaHypens
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	UCAssertAscending(comparator, @"1.0  - beta", @"1.0");
}

- (void)testPrePeriodZero
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertAscending(comparator, @"...1", @"0.0.1");
	UCAssertEqual(comparator, @"..1", @"0.0.1");
	UCAssertEqual(comparator, @".", @"0.0");
	UCAssertDescending(comparator, @".1", @"0.0.1");
	UCAssertDescending(comparator, @".1.", @"0.0.1");
}

- (void)testEquality
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertEqual(comparator, @"1.0", @"1.0");
	UCAssertEqual(comparator, @"1.0", @"1. 0");
	UCAssertEqual(comparator, @"1.0", @" 1 . 0 ");
	UCAssertEqual(comparator, @"1.0", @"1. 0 ");
	UCAssertEqual(comparator, @"1.0", @"        \t\t  1.\t0 ");
}

- (void)testNumbers
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertAscending(comparator, @"1.0", @"1.1");
	UCAssertEqual(comparator, @"1.0", @"1.0");
	UCAssertDescending(comparator, @"2.0", @"1.1");
	UCAssertDescending(comparator, @"0.1", @"0.0.1");
	UCAssertDescending(comparator, @".1", @"0.0.1");
	UCAssertAscending(comparator, @"0.1", @"0.1.2");
}

- (void)testPrereleases
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertAscending(comparator, @"1.1.0b1", @"1.1.0b2");
	UCAssertAscending(comparator, @"1.1.1b2", @"1.1.2b1");
	UCAssertAscending(comparator, @"1.1.1b2", @"1.1.2a1");
	UCAssertAscending(comparator, @"1.0a1", @"1.0b1");
	UCAssertAscending(comparator, @"1.0b1", @"1.0");
	UCAssertAscending(comparator, @"1.0b", @"1.0b2");
	UCAssertAscending(comparator, @"1.0b10", @"1.0b11");
	UCAssertAscending(comparator, @"1.0b9", @"1.0b10");
	UCAssertAscending(comparator, @"1.0rc", @"1.0");
	UCAssertAscending(comparator, @"1.0b", @"1.0");
	UCAssertAscending(comparator, @"1.0pre1", @"1.0");
}

- (void)testVersionsWithBuildNumbers
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertAscending(comparator, @"1.0 (1234)", @"1.0 (1235)");
	UCAssertAscending(comparator, @"1.0b1 (1234)", @"1.0 (1234)");
	UCAssertAscending(comparator, @"1.0b5 (1234)", @"1.0b5 (1235)");
	UCAssertAscending(comparator, @"1.0b5 (1234)", @"1.0.1b5 (1234)");
	UCAssertAscending(comparator, @"1.0.1b5 (1234)", @"1.0.1b6 (1234)");
	UCAssertAscending(comparator, @"2.0.0.2429", @"2.0.0.2430");
	UCAssertAscending(comparator, @"1.1.1.1818", @"2.0.0.2430");
}

- (void)testWordsWithSpaceInFront
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertAscending(comparator, @"1.0 beta", @"1.0");
	UCAssertAscending(comparator, @"1.0  - beta", @"1.0");
	UCAssertAscending(comparator, @"1.0 alpha", @"1.0 beta");
	UCAssertEqual(comparator, @"1.0  - beta", @"1.0beta");
	UCAssertEqual(comparator, @"1.0  - beta", @"1.0 beta");
}

- (void)testVersionsWithReverseDateBasedNumbers
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertAscending(comparator, @"201210251627", @"201211051041");
}

- (void)testUnstableVersionDetection
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	XCTAssertFalse([comparator isUnstableVersion:nil],@"stability ok");
	XCTAssertFalse([comparator isUnstableVersion:@""],@"stability ok");
	XCTAssertFalse([comparator isUnstableVersion:@"1.0"],@"stability ok");
	XCTAssertFalse([comparator isUnstableVersion:@"1"],@"stability ok");
	XCTAssertFalse([comparator isUnstableVersion:@"1.1.0"],@"stability ok");
	XCTAssertFalse([comparator isUnstableVersion:@"  1.1.0\t1"],@"stability ok");
	
	XCTAssertTrue([comparator isUnstableVersion:@"1.0a"],@"stability ok");
	XCTAssertTrue([comparator isUnstableVersion:@"1.0A"],@"stability ok");
	XCTAssertTrue([comparator isUnstableVersion:@"1.0a1"],@"stability ok");
	XCTAssertTrue([comparator isUnstableVersion:@"1.0alpha"],@"stability ok");
	XCTAssertTrue([comparator isUnstableVersion:@"1.0 alpha"],@"stability ok");
	XCTAssertTrue([comparator isUnstableVersion:@"1.0 alpha 1"],@"stability ok");
}

- (void)testVersionsWithUnstableNumbersDenied
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	
	UCAssertAscending(comparator, @"1.1b1", @"1.0");
	UCAssertAscending(comparator, @"2.1 beta", @"1.0");
	UCAssertAscending(comparator, @"1.1pr20170324", @"1.0");
	
	UCAssertDescending(comparator, @"1.2", @"1.3a4567");
	
	UCAssertDescending(comparator, @"1.5.5", @"1.5.6a1");
	UCAssertDescending(comparator, @"0.9", @"1.0a1");
	UCAssertDescending(comparator, @"3.3 (5847)", @"3.3.1b1 (5902)");
}

- (void)testVersionsWithUnstableNumbersAllowed
{
	UCVersionComparison* comparator = [UCVersionComparison new];
	comparator.allowUnstable = YES;
	
	UCAssertDescending(comparator, @"1.1b1", @"1.0");
	UCAssertDescending(comparator, @"2.1 beta", @"1.0");
	UCAssertDescending(comparator, @"1.1pr20170324", @"1.0");
	
	UCAssertAscending(comparator, @"1.2", @"1.3a4567");
	
	UCAssertAscending(comparator, @"1.5.5", @"1.5.6a1");
	UCAssertAscending(comparator, @"0.9", @"1.0a1");
	UCAssertAscending(comparator, @"3.3 (5847)", @"3.3.1b1 (5902)");
}

@end

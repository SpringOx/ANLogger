//
//  ANLoggerTests.m
//  ANLoggerTests
//
//  Created by SpringOx on 14/12/10.
//  Copyright (c) 2014年 SpringOx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ANFileLogger.h"

@interface ANLoggerTests : XCTestCase

@end

@implementation ANLoggerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//- (void)testExample {
//    // This is an example of a functional test case.
//    XCTAssert(YES, @"Pass");
//}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

- (void)testError
{
    ANLogError(@"Test error log! [SYNC]");
}

- (void)testWarn
{
     ANLogWarn(@"Test warn log! [ASYNC]");
}

- (void)testInfo
{
    ANLogInfo(@"Test info log:%@! [ASYNC]", @"info parameter");
}

- (void)testVerbose
{
    ANLogVerbose(@"Test verbose log:%@! [ASYNC]", @"verbose parameter");
}

@end

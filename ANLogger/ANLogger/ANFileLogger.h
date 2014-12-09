//
//  ANFileLogger.h
//  Araneo
//
//  Created by SpringOx on 13-10-28.
//  Copyright (c) 2013年 SpringOx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ANLogger.h"

#define DEFAULT_LOG_MAX_FILE_SIZE     (1024 * 1024)   //  1 MB
#define DEFAULT_LOG_ROLLING_FREQUENCY (60 * 60 * 24)  //  24 Hours
#define DEFAULT_LOG_MAX_NUM_LOG_FILES (5)             //  5 Files

@interface ANLogFileInfo : NSObject
{
	__strong NSString *filePath;
	__strong NSString *fileName;
	
	__strong NSDictionary *fileAttributes;
	
	__strong NSDate *creationDate;
	__strong NSDate *modificationDate;
	
	unsigned long long fileSize;
}

@property (strong, nonatomic, readonly) NSString *filePath;
@property (strong, nonatomic, readonly) NSString *fileName;

@property (strong, nonatomic, readonly) NSDictionary *fileAttributes;

@property (strong, nonatomic, readonly) NSDate *creationDate;
@property (strong, nonatomic, readonly) NSDate *modificationDate;

@property (nonatomic, readonly) unsigned long long fileSize;

@property (nonatomic, readonly) NSTimeInterval age;

@property (nonatomic, readwrite) BOOL isArchived;

+ (id)logFileWithPath:(NSString *)filePath;

- (id)initWithFilePath:(NSString *)filePath;

- (void)reset;
- (void)renameFile:(NSString *)newFileName;

#if TARGET_IPHONE_SIMULATOR

// So here's the situation.
// Extended attributes are perfect for what we're trying to do here (marking files as archived).
// This is exactly what extended attributes were designed for.
//
// But Apple screws us over on the simulator.
// Everytime you build-and-go, they copy the application into a new folder on the hard drive,
// and as part of the process they strip extended attributes from our log files.
// Normally, a copy of a file preserves extended attributes.
// So obviously Apple has gone to great lengths to piss us off.
//
// Thus we use a slightly different tactic for marking log files as archived in the simulator.
// That way it "just works" and there's no confusion when testing.
//
// The difference in method names is indicative of the difference in functionality.
// On the simulator we add an attribute by appending a filename extension.
//
// For example:
// log-ABC123.txt -> log-ABC123.archived.txt

- (BOOL)hasExtensionAttributeWithName:(NSString *)attrName;

- (void)addExtensionAttributeWithName:(NSString *)attrName;
- (void)removeExtensionAttributeWithName:(NSString *)attrName;

#else

// Normal use of extended attributes used everywhere else,
// such as on Macs and on iPhone devices.

- (BOOL)hasExtendedAttributeWithName:(NSString *)attrName;

- (void)addExtendedAttributeWithName:(NSString *)attrName;
- (void)removeExtendedAttributeWithName:(NSString *)attrName;

#endif

- (NSComparisonResult)reverseCompareByCreationDate:(ANLogFileInfo *)another;
- (NSComparisonResult)reverseCompareByModificationDate:(ANLogFileInfo *)another;

@end

@interface ANFileLogger : NSObject <ANLogger>
{
    NSUInteger maximumNumberOfLogFiles;
	NSString *_logsDirectory;
    
    NSDateFormatter *dateFormatter;
    
    dispatch_queue_t loggerQueue;
    
    ANLogFileInfo *currentLogFileInfo;
	NSFileHandle *currentLogFileHandle;
	
	dispatch_source_t rollingTimer;
	
	unsigned long long maximumFileSize;
	NSTimeInterval rollingFrequency;
}

// Public properties

/**
 * The maximum number of archived log files to keep on disk.
 * For example, if this property is set to 3,
 * then the LogFileManager will only keep 3 archived log files (plus the current active log file) on disk.
 * Once the active log file is rolled/archived, then the oldest of the existing 3 rolled/archived log files is deleted.
 *
 * You may optionally disable deleting old/rolled/archived log files by setting this property to zero.
 **/
@property (readwrite, assign) NSUInteger maximumNumberOfLogFiles;

// Public methods

- (NSString *)logsDirectory;

- (NSArray *)unsortedLogFilePaths;
- (NSArray *)unsortedLogFileNames;
- (NSArray *)unsortedLogFileInfos;

- (NSArray *)sortedLogFilePaths;
- (NSArray *)sortedLogFileNames;
- (NSArray *)sortedLogFileInfos;

// Private methods (only to be used by DDFileLogger)

- (NSString *)createNewLogFile;

/**
 * Log File Rolling:
 *
 * maximumFileSize:
 *   The approximate maximum size to allow log files to grow.
 *   If a log file is larger than this value after a log statement is appended,
 *   then the log file is rolled.
 *
 * rollingFrequency
 *   How often to roll the log file.
 *   The frequency is given as an NSTimeInterval, which is a double that specifies the interval in seconds.
 *   Once the log file gets to be this old, it is rolled.
 *
 * Both the maximumFileSize and the rollingFrequency are used to manage rolling.
 * Whichever occurs first will cause the log file to be rolled.
 *
 * For example:
 * The rollingFrequency is 24 hours,
 * but the log file surpasses the maximumFileSize after only 20 hours.
 * The log file will be rolled at that 20 hour mark.
 * A new log file will be created, and the 24 hour timer will be restarted.
 *
 * You may optionally disable rolling due to filesize by setting maximumFileSize to zero.
 * If you do so, rolling is based solely on rollingFrequency.
 *
 * You may optionally disable rolling due to time by setting rollingFrequency to zero (or any non-positive number).
 * If you do so, rolling is based solely on maximumFileSize.
 *
 * If you disable both maximumFileSize and rollingFrequency, then the log file won't ever be rolled.
 * This is strongly discouraged.
 **/
@property (readwrite, assign) unsigned long long maximumFileSize;
@property (readwrite, assign) NSTimeInterval rollingFrequency;


// You can optionally force the current log file to be rolled with this method.

- (void)rollLogFile;

@end

//
//  ANFileLogger.m
//  Araneo
//
//  Created by SpringOx on 13-10-28.
//  Copyright (c) 2013年 SpringOx. All rights reserved.
//

#import "ANFileLogger.h"

#import <unistd.h>
#import <sys/attr.h>
#import <sys/xattr.h>
#import <libkern/OSAtomic.h>

#if TARGET_IPHONE_SIMULATOR
#define BaseLog(frmt, ...)         do{} while(0)
#else
#define BaseLog(frmt, ...)         do{NSLog(frmt, ##__VA_ARGS__); } while(0)
#endif

#define LOG_LEVEL 4
#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog(@"[ERROR] "frmt, ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog(@"[WARN] "frmt, ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog(@"[INFO] "frmt, ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog(@"[VERBOSE] "frmt, ##__VA_ARGS__); } while(0)

//#if TARGET_IPHONE_SIMULATOR
#define XATTR_ARCHIVED_NAME  @"archived"
//#else
//#define XATTR_ARCHIVED_NAME  @"lumberjack.log.archived"
//#endif

extern void *GlobalLoggingQueueIdentityKey;

@implementation ANLogFileInfo

@synthesize filePath;

@dynamic fileName;
@dynamic fileAttributes;
@dynamic creationDate;
@dynamic modificationDate;
@dynamic fileSize;
@dynamic age;

@dynamic isArchived;


#pragma mark Lifecycle

+ (id)logFileWithPath:(NSString *)aFilePath
{
	return [[ANLogFileInfo alloc] initWithFilePath:aFilePath];
}

- (id)initWithFilePath:(NSString *)aFilePath
{
	if ((self = [super init]))
	{
		filePath = [aFilePath copy];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Standard Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)fileAttributes
{
	if (fileAttributes == nil)
	{
		fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
	}
	return fileAttributes;
}

- (NSString *)fileName
{
	if (fileName == nil)
	{
		fileName = [filePath lastPathComponent];
	}
	return fileName;
}

- (NSDate *)modificationDate
{
	if (modificationDate == nil)
	{
		modificationDate = [[self fileAttributes] objectForKey:NSFileModificationDate];
	}
	
	return modificationDate;
}

- (NSDate *)creationDate
{
	if (creationDate == nil)
	{
        
#if TARGET_OS_IPHONE
        
		const char *path = [filePath UTF8String];
		
		struct attrlist attrList;
		memset(&attrList, 0, sizeof(attrList));
		attrList.bitmapcount = ATTR_BIT_MAP_COUNT;
		attrList.commonattr = ATTR_CMN_CRTIME;
		
		struct {
			u_int32_t attrBufferSizeInBytes;
			struct timespec crtime;
		} attrBuffer;
		
		int result = getattrlist(path, &attrList, &attrBuffer, sizeof(attrBuffer), 0);
		if (result == 0)
		{
			double seconds = (double)(attrBuffer.crtime.tv_sec);
			double nanos   = (double)(attrBuffer.crtime.tv_nsec);
			
			NSTimeInterval ti = seconds + (nanos / 1000000000.0);
			
			creationDate = [NSDate dateWithTimeIntervalSince1970:ti];
		}
		else
		{
			BaseLog(@"*** ANLogFileInfo: creationDate(%@): getattrlist result = %i", self.fileName, result);
		}
		
#else
		
		creationDate = [[self fileAttributes] objectForKey:NSFileCreationDate];
		
#endif
		
	}
	return creationDate;
}

- (unsigned long long)fileSize
{
	if (fileSize == 0)
	{
		fileSize = [[[self fileAttributes] objectForKey:NSFileSize] unsignedLongLongValue];
	}
	
	return fileSize;
}

- (NSTimeInterval)age
{
	return [[self creationDate] timeIntervalSinceNow] * -1.0;
}

- (NSString *)description
{
	return [@{@"filePath": self.filePath ?: @"",
              @"fileName": self.fileName ?: @"",
              @"fileAttributes": self.fileAttributes ?: @"",
              @"creationDate": self.creationDate ?: @"",
              @"modificationDate": self.modificationDate ?: @"",
              @"fileSize": @(self.fileSize),
              @"age": @(self.age),
              @"isArchived": @(self.isArchived)} description];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Archiving
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isArchived
{
	
#if TARGET_IPHONE_SIMULATOR
	
	// Extended attributes don't work properly on the simulator.
	// So we have to use a less attractive alternative.
	// See full explanation in the header file.
	
	return [self hasExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
	
#else
	
	return [self hasExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	
#endif
}

- (void)setIsArchived:(BOOL)flag
{
	
#if TARGET_IPHONE_SIMULATOR
	
	// Extended attributes don't work properly on the simulator.
	// So we have to use a less attractive alternative.
	// See full explanation in the header file.
	
	if (flag)
		[self addExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
	else
		[self removeExtensionAttributeWithName:XATTR_ARCHIVED_NAME];
	
#else
	
	if (flag)
		[self addExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	else
		[self removeExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	
#endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Changes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)reset
{
	fileName = nil;
	fileAttributes = nil;
	creationDate = nil;
	modificationDate = nil;
}

- (void)renameFile:(NSString *)newFileName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	if (![newFileName isEqualToString:[self fileName]])
	{
		NSString *fileDir = [filePath stringByDeletingLastPathComponent];
		
		NSString *newFilePath = [fileDir stringByAppendingPathComponent:newFileName];
		
		BaseLog(@"*** ANLogFileInfo: Renaming file: '%@' -> '%@'", self.fileName, newFileName);
		
		NSError *error = nil;
		if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newFilePath error:&error])
		{
			BaseLog(@"*** ANLogFileInfo: Error renaming file (%@): %@", self.fileName, error);
		}
		
		filePath = newFilePath;
		[self reset];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Attribute Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if TARGET_IPHONE_SIMULATOR

// Extended attributes don't work properly on the simulator.
// So we have to use a less attractive alternative.
// See full explanation in the header file.

- (BOOL)hasExtensionAttributeWithName:(NSString *)attrName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	// Split the file name into components.
	//
	// Log-ABC123.archived.uploaded.txt
	//
	// 0. Log-ABC123
	// 1. archived
	// 2. uploaded
	// 3. txt
	//
	// So we want to search for the attrName in the components (ignoring the first and last array indexes).
	
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	
	// Watch out for file names without an extension
	
	NSUInteger count = [components count];
	NSUInteger max = (count >= 2) ? count-1 : count;
	
	NSUInteger i;
	for (i = 1; i < max; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		
		if ([attrName isEqualToString:attr])
		{
			return YES;
		}
	}
	
	return NO;
}

- (void)addExtensionAttributeWithName:(NSString *)attrName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	if ([attrName length] == 0) return;
	
	// Example:
	// attrName = "archived"
	//
	// "Log-ABC123.txt" -> "Log-ABC123.archived.txt"
	
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	
	NSUInteger count = [components count];
	
	NSUInteger estimatedNewLength = [[self fileName] length] + [attrName length] + 1;
	NSMutableString *newFileName = [NSMutableString stringWithCapacity:estimatedNewLength];
	
	if (count > 0)
	{
		[newFileName appendString:[components objectAtIndex:0]];
	}
	
	NSString *lastExt = @"";
	
	NSUInteger i;
	for (i = 1; i < count; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		if ([attr length] == 0)
		{
			continue;
		}
		
		if ([attrName isEqualToString:attr])
		{
			// Extension attribute already exists in file name
			return;
		}
		
		if ([lastExt length] > 0)
		{
			[newFileName appendFormat:@".%@", lastExt];
		}
		
		lastExt = attr;
	}
	
	[newFileName appendFormat:@".%@", attrName];
	
	if ([lastExt length] > 0)
	{
		[newFileName appendFormat:@".%@", lastExt];
	}
	
	[self renameFile:newFileName];
}

- (void)removeExtensionAttributeWithName:(NSString *)attrName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	if ([attrName length] == 0) return;
	
	// Example:
	// attrName = "archived"
	//
	// "Log-ABC123.txt" -> "Log-ABC123.archived.txt"
	
	NSArray *components = [[self fileName] componentsSeparatedByString:@"."];
	
	NSUInteger count = [components count];
	
	NSUInteger estimatedNewLength = [[self fileName] length];
	NSMutableString *newFileName = [NSMutableString stringWithCapacity:estimatedNewLength];
	
	if (count > 0)
	{
		[newFileName appendString:[components objectAtIndex:0]];
	}
	
	BOOL found = NO;
	
	NSUInteger i;
	for (i = 1; i < count; i++)
	{
		NSString *attr = [components objectAtIndex:i];
		
		if ([attrName isEqualToString:attr])
		{
			found = YES;
		}
		else
		{
			[newFileName appendFormat:@".%@", attr];
		}
	}
	
	if (found)
	{
		[self renameFile:newFileName];
	}
}

#else

- (BOOL)hasExtendedAttributeWithName:(NSString *)attrName
{
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	
	ssize_t result = getxattr(path, name, NULL, 0, 0, 0);
	
	return (result >= 0);
}

- (void)addExtendedAttributeWithName:(NSString *)attrName
{
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	
	int result = setxattr(path, name, NULL, 0, 0, 0);
	
	if (result < 0)
	{
		BaseLog(@"*** ANLogFileInfo: setxattr(%@, %@): error = %i", attrName, self.fileName, result);
	}
}

- (void)removeExtendedAttributeWithName:(NSString *)attrName
{
	const char *path = [filePath UTF8String];
	const char *name = [attrName UTF8String];
	
	int result = removexattr(path, name, 0);
	
	if (result < 0 && errno != ENOATTR)
	{
		BaseLog(@"*** ANLogFileInfo: removexattr(%@, %@): error = %i", attrName, self.fileName, result);
	}
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[self class]])
	{
		ANLogFileInfo *another = (ANLogFileInfo *)object;
		
		return [filePath isEqualToString:[another filePath]];
	}
	
	return NO;
}

- (NSComparisonResult)reverseCompareByCreationDate:(ANLogFileInfo *)another
{
	NSDate *us = [self creationDate];
	NSDate *them = [another creationDate];
	
	NSComparisonResult result = [us compare:them];
	
	if (result == NSOrderedAscending)
		return NSOrderedDescending;
	
	if (result == NSOrderedDescending)
		return NSOrderedAscending;
	
	return NSOrderedSame;
}

- (NSComparisonResult)reverseCompareByModificationDate:(ANLogFileInfo *)another
{
	NSDate *us = [self modificationDate];
	NSDate *them = [another modificationDate];
	
	NSComparisonResult result = [us compare:them];
	
	if (result == NSOrderedAscending)
		return NSOrderedDescending;
	
	if (result == NSOrderedDescending)
		return NSOrderedAscending;
	
	return NSOrderedSame;
}

@end

@interface ANFileLogger (PrivateAPI)

- (void)deleteOldLogFiles;
- (NSString *)defaultLogsDirectory;

- (void)rollLogFileNow;
- (void)maybeRollLogFileDueToAge;
- (void)maybeRollLogFileDueToSize;

@end

@implementation ANFileLogger

@synthesize maximumNumberOfLogFiles;

- (id)init
{
	return [self initWithLogsDirectory:nil];
}

- (id)initWithLogsDirectory:(NSString *)aLogsDirectory
{
	if ((self = [super init]))
	{
		maximumNumberOfLogFiles = DEFAULT_LOG_MAX_NUM_LOG_FILES;
		
		if (aLogsDirectory)
			_logsDirectory = [aLogsDirectory copy];
		else
			_logsDirectory = [[self defaultLogsDirectory] copy];
		
		NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
		
		[self addObserver:self forKeyPath:@"maximumNumberOfLogFiles" options:kvoOptions context:nil];
		
		BaseLog(@"FileLogManagerDefault: logsDirectory:\n%@", [self logsDirectory]);
		BaseLog(@"FileLogManagerDefault: sortedLogFileNames:\n%@", [self sortedLogFileNames]);
        
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4]; // 10.4+ style
        [dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
        
        const char *loggerQueueName = NULL;
		if ([self respondsToSelector:@selector(loggerName)])
		{
			loggerQueueName = [[self loggerName] UTF8String];
		}
		
		loggerQueue = dispatch_queue_create(loggerQueueName, NULL);
		
		// We're going to use dispatch_queue_set_specific() to "mark" our loggerQueue.
		// Later we can use dispatch_get_specific() to determine if we're executing on our loggerQueue.
		// The documentation states:
		//
		// > Keys are only compared as pointers and are never dereferenced.
		// > Thus, you can use a pointer to a static variable for a specific subsystem or
		// > any other value that allows you to identify the value uniquely.
		// > Specifying a pointer to a string constant is not recommended.
		//
		// So we're going to use the very convenient key of "self",
		// which also works when multiple logger classes extend this class, as each will have a different "self" key.
		//
		// This is used primarily for thread-safety assertions (via the isOnInternalLoggerQueue method below).
		
		void *key = (__bridge void *)self;
		void *nonNullValue = (__bridge void *)self;
		
		dispatch_queue_set_specific(loggerQueue, key, nonNullValue, NULL);
        
        maximumFileSize = DEFAULT_LOG_MAX_FILE_SIZE;
		rollingFrequency = DEFAULT_LOG_ROLLING_FREQUENCY;
	}
	return self;
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"maximumNumberOfLogFiles"];

#if !OS_OBJECT_USE_OBJC
	if (loggerQueue) dispatch_release(loggerQueue);
#endif
    
    [currentLogFileHandle synchronizeFile];
	[currentLogFileHandle closeFile];
	
	if (rollingTimer)
	{
		dispatch_source_cancel(rollingTimer);
		rollingTimer = NULL;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSNumber *old = [change objectForKey:NSKeyValueChangeOldKey];
	NSNumber *new = [change objectForKey:NSKeyValueChangeNewKey];
	
	if ([old isEqual:new])
	{
		// No change in value - don't bother with any processing.
		return;
	}
	
	if ([keyPath isEqualToString:@"maximumNumberOfLogFiles"])
	{
		BaseLog(@"FileLogManagerDefault: Responding to configuration change: maximumNumberOfLogFiles");
		
		dispatch_async([ANLogServer loggingQueue], ^{ @autoreleasepool {
			
			[self deleteOldLogFiles];
		}});
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Deleting
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Deletes archived log files that exceed the maximumNumberOfLogFiles configuration value.
 **/
- (void)deleteOldLogFiles
{
	BaseLog(@"LogFileManagerDefault: deleteOldLogFiles");
	
	NSUInteger maxNumLogFiles = self.maximumNumberOfLogFiles;
	if (maxNumLogFiles == 0)
	{
		// Unlimited - don't delete any log files
		return;
	}
	
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	// Do we consider the first file?
	// We are only supposed to be deleting archived files.
	// In most cases, the first file is likely the log file that is currently being written to.
	// So in most cases, we do not want to consider this file for deletion.
	
	NSUInteger count = [sortedLogFileInfos count];
	BOOL excludeFirstFile = NO;
	
	if (count > 0)
	{
		ANLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:0];
		
		if (!logFileInfo.isArchived)
		{
			excludeFirstFile = YES;
		}
	}
	
	NSArray *sortedArchivedLogFileInfos;
	if (excludeFirstFile)
	{
		count--;
		sortedArchivedLogFileInfos = [sortedLogFileInfos subarrayWithRange:NSMakeRange(1, count)];
	}
	else
	{
		sortedArchivedLogFileInfos = sortedLogFileInfos;
	}
	
	NSUInteger i;
	for (i = maxNumLogFiles; i < count; i++)
	{
		ANLogFileInfo *logFileInfo = [sortedArchivedLogFileInfos objectAtIndex:i];
		
		BaseLog(@"LogFileManagerDefault: Deleting file: %@", logFileInfo.fileName);
		
		[[NSFileManager defaultManager] removeItemAtPath:logFileInfo.filePath error:nil];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Log Files
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the path to the default logs directory.
 * If the logs directory doesn't exist, this method automatically creates it.
 **/
- (NSString *)defaultLogsDirectory
{
#if TARGET_OS_IPHONE
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *baseDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"Logs"];
    
#else
	NSString *appName = [[NSProcessInfo processInfo] processName];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	NSString *logsDirectory = [[basePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:appName];
    
#endif
    
	return logsDirectory;
}

- (NSString *)logsDirectory
{
	// We could do this check once, during initalization, and not bother again.
	// But this way the code continues to work if the directory gets deleted while the code is running.
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:_logsDirectory])
	{
		NSError *err = nil;
		if (![[NSFileManager defaultManager] createDirectoryAtPath:_logsDirectory
		                               withIntermediateDirectories:YES attributes:nil error:&err])
		{
			BaseLog(@"*** ANFileLogManagerDefault: Error creating logsDirectory: %@", err);
		}
	}
	
	return _logsDirectory;
}

- (BOOL)isLogFile:(NSString *)fileName
{
	// A log file has a name like "Log-<uuid>.txt", where <uuid> is a HEX-string of 6 characters.
	//
	// For example: Log-DFFE99.txt
	
	BOOL hasProperPrefix = [fileName hasPrefix:@"Log-"];
	
	BOOL hasProperLength = [fileName length] >= 10;
	
	
	if (hasProperPrefix && hasProperLength)
	{
		NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
		
		NSString *hex = [fileName substringWithRange:NSMakeRange(4, 6)];
		NSString *nohex = [hex stringByTrimmingCharactersInSet:hexSet];
		
		if ([nohex length] == 0)
		{
			return YES;
		}
	}
	
	return NO;
}

/**
 * Returns an array of NSString objects,
 * each of which is the filePath to an existing log file on disk.
 **/
- (NSArray *)unsortedLogFilePaths
{
	NSString *logsDirectory = [self logsDirectory];
	NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsDirectory error:nil];
	
	NSMutableArray *unsortedLogFilePaths = [NSMutableArray arrayWithCapacity:[fileNames count]];
	
	for (NSString *fileName in fileNames)
	{
		// Filter out any files that aren't log files. (Just for extra safety)
		
		if ([self isLogFile:fileName])
		{
			NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
			
			[unsortedLogFilePaths addObject:filePath];
		}
	}
	
	return unsortedLogFilePaths;
}

/**
 * Returns an array of NSString objects,
 * each of which is the fileName of an existing log file on disk.
 **/
- (NSArray *)unsortedLogFileNames
{
	NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	
	NSMutableArray *unsortedLogFileNames = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	
	for (NSString *filePath in unsortedLogFilePaths)
	{
		[unsortedLogFileNames addObject:[filePath lastPathComponent]];
	}
	
	return unsortedLogFileNames;
}

/**
 * Returns an array of DDLogFileInfo objects,
 * each representing an existing log file on disk,
 * and containing important information about the log file such as it's modification date and size.
 **/
- (NSArray *)unsortedLogFileInfos
{
	NSArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	
	NSMutableArray *unsortedLogFileInfos = [NSMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	
	for (NSString *filePath in unsortedLogFilePaths)
	{
		ANLogFileInfo *logFileInfo = [[ANLogFileInfo alloc] initWithFilePath:filePath];
		
		[unsortedLogFileInfos addObject:logFileInfo];
	}
	
	return unsortedLogFileInfos;
}

/**
 * Just like the unsortedLogFilePaths method, but sorts the array.
 * The items in the array are sorted by modification date.
 * The first item in the array will be the most recently modified log file.
 **/
- (NSArray *)sortedLogFilePaths
{
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	NSMutableArray *sortedLogFilePaths = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	
	for (ANLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFilePaths addObject:[logFileInfo filePath]];
	}
	
	return sortedLogFilePaths;
}

/**
 * Just like the unsortedLogFileNames method, but sorts the array.
 * The items in the array are sorted by modification date.
 * The first item in the array will be the most recently modified log file.
 **/
- (NSArray *)sortedLogFileNames
{
	NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	NSMutableArray *sortedLogFileNames = [NSMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	
	for (ANLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFileNames addObject:[logFileInfo fileName]];
	}
	
	return sortedLogFileNames;
}

/**
 * Just like the unsortedLogFileInfos method, but sorts the array.
 * The items in the array are sorted by modification date.
 * The first item in the array will be the most recently modified log file.
 **/
- (NSArray *)sortedLogFileInfos
{
	return [[self unsortedLogFileInfos] sortedArrayUsingSelector:@selector(reverseCompareByCreationDate:)];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Generates a short UUID suitable for use in the log file's name.
 * The result will have six characters, all in the hexadecimal set [0123456789ABCDEF].
 **/
- (NSString *)generateShortUUID
{
	CFUUIDRef uuid = CFUUIDCreate(NULL);
	
	CFStringRef fullStr = CFUUIDCreateString(NULL, uuid);
	NSString *result = (__bridge_transfer NSString *)CFStringCreateWithSubstring(NULL, fullStr, CFRangeMake(0, 6));
	
	CFRelease(fullStr);
	CFRelease(uuid);
	
	return result;
}

/**
 * Generates a new unique log file path, and creates the corresponding log file.
 **/
- (NSString *)createNewLogFile
{
	// Generate a random log file name, and create the file (if there isn't a collision)
	
	NSString *logsDirectory = [self logsDirectory];
	do
	{
		//NSString *fileName = [NSString stringWithFormat:@"Log-%@.txt", [self generateShortUUID]];
		NSString *fileName = [NSString stringWithFormat:@"Log-%@.log", [self generateShortUUID]];
        
		NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
		{
			BaseLog(@"LogFileManagerDefault: Creating new log file: %@", fileName);
			
			[[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
			
			// Since we just created a new log file, we may need to delete some old log files
			[self deleteOldLogFiles];
			
			return filePath;
		}
		
	} while(YES);
}

- (NSString *)formatLogMessage:(ANLogInfo *)logInfo
{
	NSString *dateAndTime = [dateFormatter stringFromDate:(logInfo->timestamp)];
	if (LOG_FLAG_ERROR == logInfo->flag) {
        NSLogError(@"%@", logInfo->message);
        return [NSString stringWithFormat:@"%@ [ERROR] %@", dateAndTime, logInfo->message];
    } else if (LOG_FLAG_WARN == logInfo->flag) {
        NSLogWarn(@"%@", logInfo->message);
        return [NSString stringWithFormat:@"%@ [WARN] %@", dateAndTime, logInfo->message];
    } else if (LOG_FLAG_INFO == logInfo->flag) {
        NSLogInfo(@"%@", logInfo->message);
        return [NSString stringWithFormat:@"%@ [INFO] %@", dateAndTime, logInfo->message];
    } else if (LOG_FLAG_VERBOSE == logInfo->flag) {
        NSLogVerbose(@"%@", logInfo->message);
        return [NSString stringWithFormat:@"%@ [VERBOSE] %@", dateAndTime, logInfo->message];
    } else {
        NSLog(@"%@", logInfo->message);
        return [NSString stringWithFormat:@"%@  %@", dateAndTime, logInfo->message];
    }
}

- (unsigned long long)maximumFileSize
{
	__block unsigned long long result;
	
	dispatch_block_t block = ^{
		result = maximumFileSize;
	};
	
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For extensive documentation please refer to the DDAbstractLogger implementation.
	
	// Note: The internal implementation MUST access the maximumFileSize variable directly,
	// This method is designed explicitly for external access.
	//
	// Using "self." syntax to go through this method will cause immediate deadlock.
	// This is the intended result. Fix it by accessing the ivar directly.
	// Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.
	
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	
	dispatch_queue_t globalLoggingQueue = [ANLogServer loggingQueue];
	
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, block);
	});
	
	return result;
}

- (void)setMaximumFileSize:(unsigned long long)newMaximumFileSize
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		maximumFileSize = newMaximumFileSize;
		[self maybeRollLogFileDueToSize];
		
	}};
	
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For extensive documentation please refer to the DDAbstractLogger implementation.
	
	// Note: The internal implementation MUST access the maximumFileSize variable directly,
	// This method is designed explicitly for external access.
	//
	// Using "self." syntax to go through this method will cause immediate deadlock.
	// This is the intended result. Fix it by accessing the ivar directly.
	// Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.
	
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	
	dispatch_queue_t globalLoggingQueue = [ANLogServer loggingQueue];
	
	dispatch_async(globalLoggingQueue, ^{
		dispatch_async(loggerQueue, block);
	});
}

- (NSTimeInterval)rollingFrequency
{
	__block NSTimeInterval result;
	
	dispatch_block_t block = ^{
		result = rollingFrequency;
	};
	
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For extensive documentation please refer to the DDAbstractLogger implementation.
	
	// Note: The internal implementation should access the rollingFrequency variable directly,
	// This method is designed explicitly for external access.
	//
	// Using "self." syntax to go through this method will cause immediate deadlock.
	// This is the intended result. Fix it by accessing the ivar directly.
	// Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.
	
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	
	dispatch_queue_t globalLoggingQueue = [ANLogServer loggingQueue];
	
	dispatch_sync(globalLoggingQueue, ^{
		dispatch_sync(loggerQueue, block);
	});
	
	return result;
}

- (void)setRollingFrequency:(NSTimeInterval)newRollingFrequency
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		rollingFrequency = newRollingFrequency;
		[self maybeRollLogFileDueToAge];
	}};
	
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For extensive documentation please refer to the DDAbstractLogger implementation.
	
	// Note: The internal implementation should access the rollingFrequency variable directly,
	// This method is designed explicitly for external access.
	//
	// Using "self." syntax to go through this method will cause immediate deadlock.
	// This is the intended result. Fix it by accessing the ivar directly.
	// Great strides have been take to ensure this is safe to do. Plus it's MUCH faster.
	
	NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
	NSAssert(![self isOnInternalLoggerQueue], @"MUST access ivar directly, NOT via self.* syntax.");
	
	dispatch_queue_t globalLoggingQueue = [ANLogServer loggingQueue];
	
	dispatch_async(globalLoggingQueue, ^{
		dispatch_async(loggerQueue, block);
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Rolling
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scheduleTimerToRollLogFileDueToAge
{
	if (rollingTimer)
	{
		dispatch_source_cancel(rollingTimer);
		rollingTimer = NULL;
	}
	
	if (currentLogFileInfo == nil || rollingFrequency <= 0.0)
	{
		return;
	}
	
	NSDate *logFileCreationDate = [currentLogFileInfo creationDate];
	
	NSTimeInterval ti = [logFileCreationDate timeIntervalSinceReferenceDate];
	ti += rollingFrequency;
	
	NSDate *logFileRollingDate = [NSDate dateWithTimeIntervalSinceReferenceDate:ti];
	
	BaseLog(@"FileLogger: scheduleTimerToRollLogFileDueToAge");
	BaseLog(@"FileLogger: logFileCreationDate: %@", logFileCreationDate);
	BaseLog(@"FileLogger: logFileRollingDate : %@", logFileRollingDate);
	
	rollingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, loggerQueue);
	
	dispatch_source_set_event_handler(rollingTimer, ^{ @autoreleasepool {
		
		[self maybeRollLogFileDueToAge];
		
	}});
	
#if !OS_OBJECT_USE_OBJC
	dispatch_source_t theRollingTimer = rollingTimer;
	dispatch_source_set_cancel_handler(rollingTimer, ^{
		dispatch_release(theRollingTimer);
	});
#endif
	
	uint64_t delay = (uint64_t)([logFileRollingDate timeIntervalSinceNow] * NSEC_PER_SEC);
	dispatch_time_t fireTime = dispatch_time(DISPATCH_TIME_NOW, delay);
	
	dispatch_source_set_timer(rollingTimer, fireTime, DISPATCH_TIME_FOREVER, 1.0);
	dispatch_resume(rollingTimer);
}

- (void)rollLogFile
{
	// This method is public.
	// We need to execute the rolling on our logging thread/queue.
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		[self rollLogFileNow];
	}};
	
	// The design of this method is taken from the DDAbstractLogger implementation.
	// For extensive documentation please refer to the DDAbstractLogger implementation.
	
	if ([self isOnInternalLoggerQueue])
	{
		block();
	}
	else
	{
		dispatch_queue_t globalLoggingQueue = [ANLogServer loggingQueue];
		NSAssert(![self isOnGlobalLoggingQueue], @"Core architecture requirement failure");
		
		dispatch_async(globalLoggingQueue, ^{
			dispatch_async(loggerQueue, block);
		});
	}
}

- (void)rollLogFileNow
{
	BaseLog(@"FileLogger: rollLogFileNow");
	
	if (currentLogFileHandle == nil) return;
	
	[currentLogFileHandle synchronizeFile];
	[currentLogFileHandle closeFile];
	currentLogFileHandle = nil;
	
	currentLogFileInfo.isArchived = YES;
	currentLogFileInfo = nil;
	
	if (rollingTimer)
	{
		dispatch_source_cancel(rollingTimer);
		rollingTimer = NULL;
	}
}

- (void)maybeRollLogFileDueToAge
{
	if (rollingFrequency > 0.0 && currentLogFileInfo.age >= rollingFrequency)
	{
		BaseLog(@"FileLogger: Rolling log file due to age...");
		
		[self rollLogFileNow];
	}
	else
	{
		[self scheduleTimerToRollLogFileDueToAge];
	}
}

- (void)maybeRollLogFileDueToSize
{
	// This method is called from logMessage.
	// Keep it FAST.
	
	// Note: Use direct access to maximumFileSize variable.
	// We specifically wrote our own getter/setter method to allow us to do this (for performance reasons).
	
	if (maximumFileSize > 0)
	{
		unsigned long long fileSize = [currentLogFileHandle offsetInFile];
		
		if (fileSize >= maximumFileSize)
		{
			BaseLog(@"FileLogger: Rolling log file due to size (%qu)...", fileSize);
			
			[self rollLogFileNow];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the log file that should be used.
 * If there is an existing log file that is suitable,
 * within the constraints of maximumFileSize and rollingFrequency, then it is returned.
 *
 * Otherwise a new file is created and returned.
 **/
- (ANLogFileInfo *)currentLogFileInfo
{
	if (currentLogFileInfo == nil)
	{
		NSArray *sortedLogFileInfos = [self sortedLogFileInfos];
		
		if ([sortedLogFileInfos count] > 0)
		{
			ANLogFileInfo *mostRecentLogFileInfo = [sortedLogFileInfos objectAtIndex:0];
			
			BOOL useExistingLogFile = YES;
			BOOL shouldArchiveMostRecent = NO;
			
			if (mostRecentLogFileInfo.isArchived)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = NO;
			}
			else if (maximumFileSize > 0 && mostRecentLogFileInfo.fileSize >= maximumFileSize)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = YES;
			}
			else if (rollingFrequency > 0.0 && mostRecentLogFileInfo.age >= rollingFrequency)
			{
				useExistingLogFile = NO;
				shouldArchiveMostRecent = YES;
			}
			
			if (useExistingLogFile)
			{
				BaseLog(@"FileLogger: Resuming logging with file %@", mostRecentLogFileInfo.fileName);
				
				currentLogFileInfo = mostRecentLogFileInfo;
			}
			else
			{
				if (shouldArchiveMostRecent)
				{
					mostRecentLogFileInfo.isArchived = YES;
				}
			}
		}
		
		if (currentLogFileInfo == nil)
		{
			NSString *currentLogFilePath = [self createNewLogFile];
			currentLogFileInfo = [[ANLogFileInfo alloc] initWithFilePath:currentLogFilePath];
		}
	}
	
	return currentLogFileInfo;
}

- (NSFileHandle *)currentLogFileHandle
{
	if (currentLogFileHandle == nil)
	{
		NSString *logFilePath = [[self currentLogFileInfo] filePath];
		
		currentLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
		[currentLogFileHandle seekToEndOfFile];
		
		if (currentLogFileHandle)
		{
			[self scheduleTimerToRollLogFileDueToAge];
		}
	}
	
	return currentLogFileHandle;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark DDLogger Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)logMessage:(ANLogInfo *)logInfo
{
	NSString *logMsg = [self formatLogMessage:logInfo];

	if (logMsg)
	{
		if (![logMsg hasSuffix:@"\n"])
		{
			logMsg = [logMsg stringByAppendingString:@"\n"];
		}
		
		NSData *logData = [logMsg dataUsingEncoding:NSUTF8StringEncoding];
		
		[[self currentLogFileHandle] writeData:logData];
		
		[self maybeRollLogFileDueToSize];
	}
}

- (void)willRemoveLogger
{
	// If you override me be sure to invoke [super willRemoveLogger];
	
	[self rollLogFileNow];
}

- (dispatch_queue_t)loggerQueue
{
	return loggerQueue;
}

- (NSString *)loggerName
{
	return NSStringFromClass([self class]);
}

- (BOOL)isOnGlobalLoggingQueue
{
	return (dispatch_get_specific(GlobalLoggingQueueIdentityKey) != NULL);
}

- (BOOL)isOnInternalLoggerQueue
{
	void *key = (__bridge void *)self;
	return (dispatch_get_specific(key) != NULL);
}

@end

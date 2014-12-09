//
//  ANLogger.h
//  Araneo
//
//  Created by SpringOx on 13-7-25.
//  Copyright (c) 2013年 SpringOx. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef _ANLog_h
#define _ANLog_h

#if DEBUG
#define ANLogLevel  LOG_LEVEL_VERBOSE
#else
#define ANLogLevel  LOG_LEVEL_INFO
#endif

#define LOG_MACRO(isAsynchronous, lvl, flg, ctx, atag, fnct, frmt, ...) \
[ANLogServer log:isAsynchronous                                             \
level:lvl                                                        \
flag:flg                                                        \
context:ctx                                                        \
file:__FILE__                                                   \
function:fnct                                                       \
line:__LINE__                                                   \
tag:atag                                                       \
format:(frmt), ##__VA_ARGS__]

/**
 * Define the Objective-C and C versions of the macro.
 * These automatically inject the proper function name for either an objective-c method or c function.
 *
 * We also define shorthand versions for asynchronous and synchronous logging.
 **/

#define LOG_OBJC_MACRO(async, lvl, flg, ctx, frmt, ...) \
LOG_MACRO(async, lvl, flg, ctx, nil, sel_getName(_cmd), frmt, ##__VA_ARGS__)

#define LOG_C_MACRO(async, lvl, flg, ctx, frmt, ...) \
LOG_MACRO(async, lvl, flg, ctx, nil, __FUNCTION__, frmt, ##__VA_ARGS__)

#define  SYNC_LOG_OBJC_MACRO(lvl, flg, ctx, frmt, ...) \
LOG_OBJC_MACRO( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)

#define ASYNC_LOG_OBJC_MACRO(lvl, flg, ctx, frmt, ...) \
LOG_OBJC_MACRO(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)

#define  SYNC_LOG_C_MACRO(lvl, flg, ctx, frmt, ...) \
LOG_C_MACRO( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)

#define ASYNC_LOG_C_MACRO(lvl, flg, ctx, frmt, ...) \
LOG_C_MACRO(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)

/**
 * Define version of the macro that only execute if the logLevel is above the threshold.
 * The compiled versions essentially look like this:
 *
 * if (logFlagForThisLogMsg & ANLogLevel) { execute log message }
 *
 * As shown further below, Lumberjack actually uses a bitmask as opposed to primitive log levels.
 * This allows for a great amount of flexibility and some pretty advanced fine grained logging techniques.
 *
 * Note that when compiler optimizations are enabled (as they are for your release builds),
 * the log messages above your logging threshold will automatically be compiled out.
 *
 * (If the compiler sees ANLogLevel declared as a constant, the compiler simply checks to see if the 'if' statement
 *  would execute, and if not it strips it from the binary.)
 *
 * We also define shorthand versions for asynchronous and synchronous logging.
 **/

#define LOG_MAYBE(async, lvl, flg, ctx, fnct, frmt, ...) \
do { if(lvl & flg) LOG_MACRO(async, lvl, flg, ctx, nil, fnct, frmt, ##__VA_ARGS__); } while(0)

#define LOG_OBJC_MAYBE(async, lvl, flg, ctx, frmt, ...) \
LOG_MAYBE(async, lvl, flg, ctx, sel_getName(_cmd), frmt, ##__VA_ARGS__)

#define LOG_C_MAYBE(async, lvl, flg, ctx, frmt, ...) \
LOG_MAYBE(async, lvl, flg, ctx, __FUNCTION__, frmt, ##__VA_ARGS__)

#define  SYNC_LOG_OBJC_MAYBE(lvl, flg, ctx, frmt, ...) \
LOG_OBJC_MAYBE( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)

#define ASYNC_LOG_OBJC_MAYBE(lvl, flg, ctx, frmt, ...) \
LOG_OBJC_MAYBE(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)

#define  SYNC_LOG_C_MAYBE(lvl, flg, ctx, frmt, ...) \
LOG_C_MAYBE( NO, lvl, flg, ctx, frmt, ##__VA_ARGS__)

#define ASYNC_LOG_C_MAYBE(lvl, flg, ctx, frmt, ...) \
LOG_C_MAYBE(YES, lvl, flg, ctx, frmt, ##__VA_ARGS__)

/**
 * Define versions of the macros that also accept tags.
 *
 * The DDLogMessage object includes a 'tag' ivar that may be used for a variety of purposes.
 * It may be used to pass custom information to loggers or formatters.
 * Or it may be used by 3rd party extensions to the framework.
 *
 * Thes macros just make it a little easier to extend logging functionality.
 **/

#define LOG_OBJC_TAG_MACRO(async, lvl, flg, ctx, tag, frmt, ...) \
LOG_MACRO(async, lvl, flg, ctx, tag, sel_getName(_cmd), frmt, ##__VA_ARGS__)

#define LOG_C_TAG_MACRO(async, lvl, flg, ctx, tag, frmt, ...) \
LOG_MACRO(async, lvl, flg, ctx, tag, __FUNCTION__, frmt, ##__VA_ARGS__)

#define LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, fnct, frmt, ...) \
do { if(lvl & flg) LOG_MACRO(async, lvl, flg, ctx, tag, fnct, frmt, ##__VA_ARGS__); } while(0)

#define LOG_OBJC_TAG_MAYBE(async, lvl, flg, ctx, tag, frmt, ...) \
LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, sel_getName(_cmd), frmt, ##__VA_ARGS__)

#define LOG_C_TAG_MAYBE(async, lvl, flg, ctx, tag, frmt, ...) \
LOG_TAG_MAYBE(async, lvl, flg, ctx, tag, __FUNCTION__, frmt, ##__VA_ARGS__)

/**
 * Define the standard options.
 *
 * We default to only 4 levels because it makes it easier for beginners
 * to make the transition to a logging framework.
 *
 * More advanced users may choose to completely customize the levels (and level names) to suite their needs.
 * For more information on this see the "Custom Log Levels" page:
 * https://github.com/robbiehanson/CocoaLumberjack/wiki/CustomLogLevels
 *
 * Advanced users may also notice that we're using a bitmask.
 * This is to allow for custom fine grained logging:
 * https://github.com/robbiehanson/CocoaLumberjack/wiki/FineGrainedLogging
 *
 * -- Flags --
 *
 * Typically you will use the LOG_LEVELS (see below), but the flags may be used directly in certain situations.
 * For example, say you have a lot of warning log messages, and you wanted to disable them.
 * However, you still needed to see your error and info log messages.
 * You could accomplish that with the following:
 *
 * static const int ANLogLevel = LOG_FLAG_ERROR | LOG_FLAG_INFO;
 *
 * Flags may also be consulted when writing custom log formatters,
 * as the DDLogMessage class captures the individual flag that caused the log message to fire.
 *
 * -- Levels --
 *
 * Log levels are simply the proper bitmask of the flags.
 *
 * -- Booleans --
 *
 * The booleans may be used when your logging code involves more than one line.
 * For example:
 *
 * if (LOG_VERBOSE) {
 *     for (id sprocket in sprockets)
 *         DDLogVerbose(@"sprocket: %@", [sprocket description])
 * }
 *
 * -- Async --
 *
 * Defines the default asynchronous options.
 * The default philosophy for asynchronous logging is very simple:
 *
 * Log messages with errors should be executed synchronously.
 *     After all, an error just occurred. The application could be unstable.
 *
 * All other log messages, such as debug output, are executed asynchronously.
 *     After all, if it wasn't an error, then it was just informational output,
 *     or something the application was easily able to recover from.
 *
 * -- Changes --
 *
 * You are strongly discouraged from modifying this file.
 * If you do, you make it more difficult on yourself to merge future bug fixes and improvements from the project.
 * Instead, create your own MyLogging.h or ApplicationNameLogging.h or CompanyLogging.h
 *
 * For an example of customizing your logging experience, see the "Custom Log Levels" page:
 * https://github.com/robbiehanson/CocoaLumberjack/wiki/CustomLogLevels
 **/

#define LOG_FLAG_ERROR    (1 << 0)  // 0...0001
#define LOG_FLAG_WARN     (1 << 1)  // 0...0010
#define LOG_FLAG_INFO     (1 << 2)  // 0...0100
#define LOG_FLAG_VERBOSE  (1 << 3)  // 0...1000

#define LOG_LEVEL_OFF     0
#define LOG_LEVEL_ERROR   (LOG_FLAG_ERROR)                                                    // 0...0001
#define LOG_LEVEL_WARN    (LOG_FLAG_ERROR | LOG_FLAG_WARN)                                    // 0...0011
#define LOG_LEVEL_INFO    (LOG_FLAG_ERROR | LOG_FLAG_WARN | LOG_FLAG_INFO)                    // 0...0111
#define LOG_LEVEL_VERBOSE (LOG_FLAG_ERROR | LOG_FLAG_WARN | LOG_FLAG_INFO | LOG_FLAG_VERBOSE) // 0...1111

#define LOG_ERROR   (ANLogLevel & LOG_FLAG_ERROR)
#define LOG_WARN    (ANLogLevel & LOG_FLAG_WARN)
#define LOG_INFO    (ANLogLevel & LOG_FLAG_INFO)
#define LOG_VERBOSE (ANLogLevel & LOG_FLAG_VERBOSE)

#define LOG_ASYNC_ENABLED YES

#define LOG_ASYNC_ERROR   ( NO && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_WARN    (YES && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_INFO    (YES && LOG_ASYNC_ENABLED)
#define LOG_ASYNC_VERBOSE (YES && LOG_ASYNC_ENABLED)

#define ANLogError(frmt, ...)   LOG_OBJC_MAYBE(LOG_ASYNC_ERROR,   ANLogLevel, LOG_FLAG_ERROR,   0, frmt, ##__VA_ARGS__)
#define ANLogWarn(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_WARN,    ANLogLevel, LOG_FLAG_WARN,    0, frmt, ##__VA_ARGS__)
#define ANLogInfo(frmt, ...)    LOG_OBJC_MAYBE(LOG_ASYNC_INFO,    ANLogLevel, LOG_FLAG_INFO,    0, frmt, ##__VA_ARGS__)
#define ANLogVerbose(frmt, ...) LOG_OBJC_MAYBE(LOG_ASYNC_VERBOSE, ANLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)

#define ANLogCError(frmt, ...)   LOG_C_MAYBE(LOG_ASYNC_ERROR,   ANLogLevel, LOG_FLAG_ERROR,   0, frmt, ##__VA_ARGS__)
#define ANLogCWarn(frmt, ...)    LOG_C_MAYBE(LOG_ASYNC_WARN,    ANLogLevel, LOG_FLAG_WARN,    0, frmt, ##__VA_ARGS__)
#define ANLogCInfo(frmt, ...)    LOG_C_MAYBE(LOG_ASYNC_INFO,    ANLogLevel, LOG_FLAG_INFO,    0, frmt, ##__VA_ARGS__)
#define ANLogCVerbose(frmt, ...) LOG_C_MAYBE(LOG_ASYNC_VERBOSE, ANLogLevel, LOG_FLAG_VERBOSE, 0, frmt, ##__VA_ARGS__)

#endif

/**
 * The DDLogMessage class encapsulates information about the log message.
 * If you write custom loggers or formatters, you will be dealing with objects of this class.
 **/

enum {
	ANLogInfoCopyFile     = 1 << 0,
	ANLogInfoCopyFunction = 1 << 1
};
typedef int ANLogInfoOptions;

NSString *DDExtractFileNameWithoutExtension(const char *filePath, BOOL copy);

@protocol ANLogger;
@protocol ANLogFormat;

@class ANLogInfo;
@class ANLogServer;

@protocol ANLogger <NSObject>

@required
/*
 */
- (void)logMessage:(ANLogInfo *)logInfo;

@optional
/**
 * Since logging is asynchronous, adding and removing loggers is also asynchronous.
 * In other words, the loggers are added and removed at appropriate times with regards to log messages.
 *
 * - Loggers will not receive log messages that were executed prior to when they were added.
 * - Loggers will not receive log messages that were executed after they were removed.
 *
 * These methods are executed in the logging thread/queue.
 * This is the same thread/queue that will execute every logMessage: invocation.
 * Loggers may use these methods for thread synchronization or other setup/teardown tasks.
 **/
- (void)didAddLogger;
- (void)willRemoveLogger;
/*
 */
- (void)flush;
/*
 */
- (dispatch_queue_t)loggerQueue;
/*
 */
- (NSString *)loggerName;

// For thread-safety assertions
- (BOOL)isOnGlobalLoggingQueue;
- (BOOL)isOnInternalLoggerQueue;

@end

@interface ANLogInfo : NSObject
{
    
    // The public variables below can be accessed directly (for speed).
    // For example: logMessage->logLevel
    
@public
	int level;
	int flag;
	int context;
	NSString *message;
	NSDate *timestamp;
	char *file;
	char *function;
	int lineNumber;
	mach_port_t machThreadID;
    char *queueLabel;
	NSString *threadName;
	
	// For 3rd party extensions to the framework, where flags and contexts aren't enough.
	id tag;
	
	// For 3rd party extensions that manually create DDLogMessage instances.
	ANLogInfoOptions options;
}

- (id)initWithMessage:(NSString *)_msg
                level:(int)_level
                 flag:(int)_flag
              context:(int)_context
                 file:(const char *)_file
             function:(const char *)_function
                 line:(int)_line
                  tag:(id)_tag
              options:(ANLogInfoOptions)optionsMask;

/**
 * Returns the function variable in NSString form.
 **/
- (NSString *)methodName;

@end

@interface ANLoggerNode : NSObject {
    
@public
	id <ANLogger> logger;
	dispatch_queue_t loggerQueue;
}

+ (ANLoggerNode *)nodeWithLogger:(id <ANLogger>)logger loggerQueue:(dispatch_queue_t)loggerQueue;

@end

@interface ANLogServer : NSObject

/**
 */
+ (void)startWithLoggers:(NSArray *)loggers;

/**
 * Provides access to the underlying logging queue.
 * This may be helpful to Logger classes for things like thread synchronization.
 **/

+ (dispatch_queue_t)loggingQueue;

/**
 * Logging Primitive.
 *
 * This method is used by the macros above.
 * It is suggested you stick with the macros as they're easier to use.
 **/

+ (void)log:(BOOL)synchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format, ... __attribute__ ((format (__NSString__, 9, 10)));

/**
 * Logging Primitive.
 *
 * This method can be used if you have a prepared va_list.
 **/

+ (void)log:(BOOL)asynchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format
       args:(va_list)argList;


/**
 * Since logging can be asynchronous, there may be times when you want to flush the logs.
 * The framework invokes this automatically when the application quits.
 **/

+ (void)flushLog;

/**
 * Loggers
 *
 * If you want your log statements to go somewhere,
 * you should create and add a logger.
 **/

+ (void)addLogger:(id <ANLogger>)logger;
+ (void)removeLogger:(id <ANLogger>)logger;

+ (void)removeAllLoggers;

@end

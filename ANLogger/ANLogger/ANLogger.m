//
//  ANLogger.m
//  Araneo
//
//  Created by SpringOx on 13-7-25.
//  Copyright (c) 2013年 SpringOx. All rights reserved.
//

#import "ANLogger.h"

#import <pthread.h>
#import <objc/runtime.h>
#import <mach/mach_host.h>
#import <mach/host_info.h>

#define LOG_MAX_QUEUE_SIZE 1000 // Should not exceed INT32_MAX

// The "global logging queue" refers to [DDLog loggingQueue].
// It is the queue that all log statements go through.
//
// The logging queue sets a flag via dispatch_queue_set_specific using this key.
// We can check for this key via dispatch_get_specific() to see if we're on the "global logging queue".

void *const GlobalLoggingQueueIdentityKey = (void *)&GlobalLoggingQueueIdentityKey;

@implementation ANLogInfo

static char *dd_str_copy(const char *str)
{
	if (str == NULL) return NULL;
	
	size_t length = strlen(str);
	char * result = malloc(length + 1);
	if (result == NULL) return NULL;
	strncpy(result, str, length);
	result[length] = 0;
	
	return result;
}

- (id)initWithMessage:(NSString *)_msg
                level:(int)_level
                 flag:(int)_flag
              context:(int)_context
                 file:(const char *)_file
             function:(const char *)_function
                 line:(int)_line
                  tag:(id)_tag
              options:(ANLogInfoOptions)optionsMask
{
	if ((self = [super init]))
	{
		message     = _msg;
		level   = _level;
		flag    = _flag;
		context = _context;
		lineNumber = _line;
		tag        = _tag;
		options    = optionsMask;
		
		if (options & ANLogInfoCopyFile)
			file = dd_str_copy(_file);
		else
			file = (char *)_file;
		
		if (options & ANLogInfoCopyFunction)
			function = dd_str_copy(_function);
		else
			function = (char *)_function;
			
		timestamp = [[NSDate alloc] init];
		
		machThreadID = pthread_mach_thread_np(pthread_self());
		
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		// The documentation for dispatch_get_current_queue() states:
		//
		// > [This method is] "recommended for debugging and logging purposes only"...
		//
		// Well that's exactly how we're using it here. Literally for logging purposes only.
		// However, Apple has decided to deprecate this method anyway.
		// However they have not given us an alternate version of dispatch_queue_get_label() that
		// automatically uses the current queue, thus dispatch_get_current_queue() is still required.
		//
		// If dispatch_get_current_queue() disappears, without a dispatch_queue_get_label() alternative,
		// Apple will have effectively taken away our ability to properly log the name of executing dispatch queue.
		
		dispatch_queue_t currentQueue = dispatch_get_current_queue();
#pragma clang diagnostic pop
		
		queueLabel = dd_str_copy(dispatch_queue_get_label(currentQueue));
		
		threadName = [[NSThread currentThread] name];
	}
	return self;
}

- (NSString *)threadID
{
	return [[NSString alloc] initWithFormat:@"%x", machThreadID];
}

- (NSString *)fileName
{
	return DDExtractFileNameWithoutExtension(file, NO);
}

- (NSString *)methodName
{
	if (function == NULL)
		return nil;
	else
		return [[NSString alloc] initWithUTF8String:function];
}

- (void)dealloc
{
	if (file && (options & ANLogInfoCopyFile))
		free(file);
	
	if (function && (options & ANLogInfoCopyFunction))
		free(function);
	
	if (queueLabel)
		free(queueLabel);
}

@end

@implementation ANLoggerNode

- (id)initWithLogger:(id <ANLogger>)aLogger loggerQueue:(dispatch_queue_t)aLoggerQueue
{
	if ((self = [super init]))
	{
		logger = aLogger;
		
		if (aLoggerQueue) {
			loggerQueue = aLoggerQueue;
#if !OS_OBJECT_USE_OBJC
			dispatch_retain(loggerQueue);
#endif
		}
	}
	return self;
}

+ (ANLoggerNode *)nodeWithLogger:(id <ANLogger>)logger loggerQueue:(dispatch_queue_t)loggerQueue
{
	return [[ANLoggerNode alloc] initWithLogger:logger loggerQueue:loggerQueue];
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
	if (loggerQueue) dispatch_release(loggerQueue);
#endif
}

@end

@interface ANLogServer (PrivateAPI)

+ (void)queueLogMessage:(ANLogInfo *)logInfo asynchronously:(BOOL)asyncFlag;
+ (void)lt_addLogger:(id <ANLogger>)logger;
+ (void)lt_removeLogger:(id <ANLogger>)logger;
+ (void)lt_removeAllLoggers;
+ (void)lt_log:(ANLogInfo *)logInfo asynchronously:(BOOL)asyncFlag;
+ (void)lt_flush;

@end

@implementation ANLogServer

// An array used to manage all the individual loggers.
// The array is only modified on the loggingQueue/loggingThread.
static NSMutableArray *loggers;

// All logging statements are added to the same queue to ensure FIFO operation.
static dispatch_queue_t loggingQueue;

// Individual loggers are executed concurrently per log statement.
// Each logger has it's own associated queue, and a dispatch group is used for synchrnoization.
static dispatch_group_t loggingGroup;

// In order to prevent to queue from growing infinitely large,
// a maximum size is enforced (LOG_MAX_QUEUE_SIZE).
static dispatch_semaphore_t queueSemaphore;

// Minor optimization for uniprocessor machines
static unsigned int numProcessors;

/**
 * The runtime sends initialize to each class in a program exactly one time just before the class,
 * or any class that inherits from it, is sent its first message from within the program. (Thus the
 * method may never be invoked if the class is not used.) The runtime sends the initialize message to
 * classes in a thread-safe manner. Superclasses receive this message before their subclasses.
 *
 * This method may also be called directly (assumably by accident), hence the safety mechanism.
 **/
+ (void)initialize
{
    static dispatch_once_t _oncePredicate;
    dispatch_once(&_oncePredicate, ^{
    
		loggers = [[NSMutableArray alloc] initWithCapacity:1];
		
        NSString *bi = [NSBundle mainBundle].bundleIdentifier;
		loggingQueue = dispatch_queue_create([bi UTF8String], NULL);
		loggingGroup = dispatch_group_create();
		
		void *nonNullValue = GlobalLoggingQueueIdentityKey; // Whatever, just not null
		dispatch_queue_set_specific(loggingQueue, GlobalLoggingQueueIdentityKey, nonNullValue, NULL);
		
		queueSemaphore = dispatch_semaphore_create(LOG_MAX_QUEUE_SIZE);
		
		// Figure out how many processors are available.
		// This may be used later for an optimization on uniprocessor machines.
		
		host_basic_info_data_t hostInfo;
		mach_msg_type_number_t infoCount;
		
		infoCount = HOST_BASIC_INFO_COUNT;
		host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount);
		
		unsigned int result = (unsigned int)(hostInfo.max_cpus);
		unsigned int one    = (unsigned int)(1);
		
		numProcessors = MAX(result, one);
		
#if TARGET_OS_IPHONE
		NSString *notificationName = @"UIApplicationWillTerminateNotification";
#else
		NSString *notificationName = @"NSApplicationWillTerminateNotification";
#endif
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(applicationWillTerminate:)
		                                             name:notificationName
		                                           object:nil];
	});
}

+ (void)startWithLoggers:(NSArray *)loggers
{
    if (0 == [loggers count]) {return;};
    
    for (id <ANLogger>logger in loggers)
    {
        [self addLogger:logger];
    }
}

/**
 * Provides access to the logging queue.
 **/
+ (dispatch_queue_t)loggingQueue
{
	return loggingQueue;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)applicationWillTerminate:(NSNotification *)notification
{
	[self flushLog];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logger Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)addLogger:(id <ANLogger>)logger
{
	if (logger == nil) return;
    
	dispatch_async(loggingQueue, ^{ @autoreleasepool {
		
		[self lt_addLogger:logger];
	}});
}

+ (void)removeLogger:(id <ANLogger>)logger
{
	if (logger == nil) return;
	
	dispatch_async(loggingQueue, ^{ @autoreleasepool {
		
		[self lt_removeLogger:logger];
	}});
}

+ (void)removeAllLoggers
{
	dispatch_async(loggingQueue, ^{ @autoreleasepool {
		
		[self lt_removeAllLoggers];
	}});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Master Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)log:(BOOL)asynchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format, ...
{
	va_list args;
	if (format)
	{
		va_start(args, format);
		
        // Control the log output by levels been defined
        if (0 == (level & flag)) {
            return;
        }
        
		NSString *logMsg = [[NSString alloc] initWithFormat:format arguments:args];
        ANLogInfo *logInfo = [[ANLogInfo alloc] initWithMessage:logMsg
                                                          level:level
                                                           flag:flag
                                                        context:context
                                                           file:file
                                                       function:function
                                                           line:line
                                                            tag:tag
                                                        options:0];
		
		[self queueLogMessage:logInfo asynchronously:asynchronous];
		
		va_end(args);
	}
}

+ (void)log:(BOOL)asynchronous
      level:(int)level
       flag:(int)flag
    context:(int)context
       file:(const char *)file
   function:(const char *)function
       line:(int)line
        tag:(id)tag
     format:(NSString *)format
       args:(va_list)args
{
	if (format)
	{
		NSString *logMsg = [[NSString alloc] initWithFormat:format arguments:args];
        ANLogInfo *logInfo = [[ANLogInfo alloc] initWithMessage:logMsg
                                                          level:level
                                                           flag:flag
                                                        context:context
                                                           file:file
                                                       function:function
                                                           line:line
                                                            tag:tag
                                                        options:0];
		
		[self queueLogMessage:logInfo asynchronously:asynchronous];
	}
}

+ (void)flushLog
{
	dispatch_sync(loggingQueue, ^{ @autoreleasepool {
		
		[self lt_flush];
	}});
}

+ (void)queueLogMessage:(ANLogInfo *)logInfo asynchronously:(BOOL)asyncFlag
{
	// We have a tricky situation here...
	//
	// In the common case, when the queueSize is below the maximumQueueSize,
	// we want to simply enqueue the logMessage. And we want to do this as fast as possible,
	// which means we don't want to block and we don't want to use any locks.
	//
	// However, if the queueSize gets too big, we want to block.
	// But we have very strict requirements as to when we block, and how long we block.
	//
	// The following example should help illustrate our requirements:
	//
	// Imagine that the maximum queue size is configured to be 5,
	// and that there are already 5 log messages queued.
	// Let us call these 5 queued log messages A, B, C, D, and E. (A is next to be executed)
	//
	// Now if our thread issues a log statement (let us call the log message F),
	// it should block before the message is added to the queue.
	// Furthermore, it should be unblocked immediately after A has been unqueued.
	//
	// The requirements are strict in this manner so that we block only as long as necessary,
	// and so that blocked threads are unblocked in the order in which they were blocked.
	//
	// Returning to our previous example, let us assume that log messages A through E are still queued.
	// Our aforementioned thread is blocked attempting to queue log message F.
	// Now assume we have another separate thread that attempts to issue log message G.
	// It should block until log messages A and B have been unqueued.
	
	
	// We are using a counting semaphore provided by GCD.
	// The semaphore is initialized with our LOG_MAX_QUEUE_SIZE value.
	// Everytime we want to queue a log message we decrement this value.
	// If the resulting value is less than zero,
	// the semaphore function waits in FIFO order for a signal to occur before returning.
	//
	// A dispatch semaphore is an efficient implementation of a traditional counting semaphore.
	// Dispatch semaphores call down to the kernel only when the calling thread needs to be blocked.
	// If the calling semaphore does not need to block, no kernel call is made.
	
	dispatch_semaphore_wait(queueSemaphore, DISPATCH_TIME_FOREVER);
	
	// We've now sure we won't overflow the queue.
	// It is time to queue our log message.
	
	dispatch_block_t logBlock = ^{ @autoreleasepool {
		
		[self lt_log:logInfo asynchronously:asyncFlag];
	}};
	
	if (asyncFlag)
		dispatch_async(loggingQueue, logBlock);
	else
		dispatch_sync(loggingQueue, logBlock);
}

/**
 * This method should only be run on the logging thread/queue.
 **/
+ (void)lt_addLogger:(id <ANLogger>)logger
{
	// Add to loggers array.
	// Need to create loggerQueue if loggerNode doesn't provide one.
	
	dispatch_queue_t loggerQueue = NULL;
	
	if ([logger respondsToSelector:@selector(loggerQueue)])
	{
		// Logger may be providing its own queue
		
		loggerQueue = [logger loggerQueue];
	}
	
	if (loggerQueue == nil)
	{
		// Automatically create queue for the logger.
		// Use the logger name as the queue name if possible.
		
		const char *loggerQueueName = NULL;
		if ([logger respondsToSelector:@selector(loggerName)])
		{
			loggerQueueName = [[logger loggerName] UTF8String];
		}
		
		loggerQueue = dispatch_queue_create(loggerQueueName, NULL);
	}
	
	ANLoggerNode *loggerNode = [ANLoggerNode nodeWithLogger:logger loggerQueue:loggerQueue];
	[loggers addObject:loggerNode];
	
	if ([logger respondsToSelector:@selector(didAddLogger)])
	{
		dispatch_async(loggerNode->loggerQueue, ^{ @autoreleasepool {
			
			[logger didAddLogger];
		}});
	}
}

/**
 * This method should only be run on the logging thread/queue.
 **/
+ (void)lt_removeLogger:(id <ANLogger>)logger
{
	// Find associated loggerNode in list of added loggers
	
	ANLoggerNode *loggerNode = nil;
	
	for (ANLoggerNode *node in loggers)
	{
		if (node->logger == logger)
		{
			loggerNode = node;
			break;
		}
	}
	
	if (loggerNode == nil)
	{
		return;
	}
	
	// Notify logger
	
	if ([logger respondsToSelector:@selector(willRemoveLogger)])
	{
		dispatch_async(loggerNode->loggerQueue, ^{ @autoreleasepool {
			
			[logger willRemoveLogger];
		}});
	}
	
	// Remove from loggers array
	
	[loggers removeObject:loggerNode];
}

/**
 * This method should only be run on the logging thread/queue.
 **/
+ (void)lt_removeAllLoggers
{
	// Notify all loggers
	
	for (ANLoggerNode *loggerNode in loggers)
	{
		if ([loggerNode->logger respondsToSelector:@selector(willRemoveLogger)])
		{
			dispatch_async(loggerNode->loggerQueue, ^{ @autoreleasepool {
				
				[loggerNode->logger willRemoveLogger];
			}});
		}
	}
	
	// Remove all loggers from array
	
	[loggers removeAllObjects];
}

/**
 * This method should only be run on the logging thread/queue.
 **/
+ (void)lt_log:(ANLogInfo *)logInfo asynchronously:(BOOL)asyncFlag
{
	// Execute the given log message on each of our loggers.
    
    // Group不是一般的异步，应该是能够支持并发线程的，所以要捕捉外部对异步是否禁止
	if (numProcessors > 1 && asyncFlag)
	{
		// Execute each logger concurrently, each within its own queue.
		// All blocks are added to same group.
		// After each block has been queued, wait on group.
		//
		// The waiting ensures that a slow logger doesn't end up with a large queue of pending log messages.
		// This would defeat the purpose of the efforts we made earlier to restrict the max queue size.
		
		for (ANLoggerNode *loggerNode in loggers)
		{
			dispatch_group_async(loggingGroup, loggerNode->loggerQueue, ^{ @autoreleasepool {
				
				[loggerNode->logger logMessage:logInfo];
                
			}});
		}
		
		dispatch_group_wait(loggingGroup, DISPATCH_TIME_FOREVER);
	}
	else
	{
		// Execute each logger serialy, each within its own queue.
		
		for (ANLoggerNode *loggerNode in loggers)
		{
			dispatch_sync(loggerNode->loggerQueue, ^{ @autoreleasepool {
				
				[loggerNode->logger logMessage:logInfo];
				
			}});
		}
	}
	
	// If our queue got too big, there may be blocked threads waiting to add log messages to the queue.
	// Since we've now dequeued an item from the log, we may need to unblock the next thread.
	
	// We are using a counting semaphore provided by GCD.
	// The semaphore is initialized with our LOG_MAX_QUEUE_SIZE value.
	// When a log message is queued this value is decremented.
	// When a log message is dequeued this value is incremented.
	// If the value ever drops below zero,
	// the queueing thread blocks and waits in FIFO order for us to signal it.
	//
	// A dispatch semaphore is an efficient implementation of a traditional counting semaphore.
	// Dispatch semaphores call down to the kernel only when the calling thread needs to be blocked.
	// If the calling semaphore does not need to block, no kernel call is made.
	
	dispatch_semaphore_signal(queueSemaphore);
}

/**
 * This method should only be run on the background logging thread.
 **/
+ (void)lt_flush
{
	// All log statements issued before the flush method was invoked have now been executed.
	//
	// Now we need to propogate the flush request to any loggers that implement the flush method.
	// This is designed for loggers that buffer IO.
    
	for (ANLoggerNode *loggerNode in loggers)
	{
		if ([loggerNode->logger respondsToSelector:@selector(flush)])
		{
			dispatch_group_async(loggingGroup, loggerNode->loggerQueue, ^{ @autoreleasepool {
				
				[loggerNode->logger flush];
				
			}});
		}
	}
	
	dispatch_group_wait(loggingGroup, DISPATCH_TIME_FOREVER);
}

NSString *DDExtractFileNameWithoutExtension(const char *filePath, BOOL copy)
{
	if (filePath == NULL) return nil;
	
	char *lastSlash = NULL;
	char *lastDot = NULL;
	
	char *p = (char *)filePath;
	
	while (*p != '\0')
	{
		if (*p == '/')
			lastSlash = p;
		else if (*p == '.')
			lastDot = p;
		
		p++;
	}
	
	char *subStr;
	NSUInteger subLen;
	
	if (lastSlash)
	{
		if (lastDot)
		{
			// lastSlash -> lastDot
			subStr = lastSlash + 1;
			subLen = lastDot - subStr;
		}
		else
		{
			// lastSlash -> endOfString
			subStr = lastSlash + 1;
			subLen = p - subStr;
		}
	}
	else
	{
		if (lastDot)
		{
			// startOfString -> lastDot
			subStr = (char *)filePath;
			subLen = lastDot - subStr;
		}
		else
		{
			// startOfString -> endOfString
			subStr = (char *)filePath;
			subLen = p - subStr;
		}
	}
	
	if (copy)
	{
		return [[NSString alloc] initWithBytes:subStr
		                                length:subLen
		                              encoding:NSUTF8StringEncoding];
	}
	else
	{
		// We can take advantage of the fact that __FILE__ is a string literal.
		// Specifically, we don't need to waste time copying the string.
		// We can just tell NSString to point to a range within the string literal.
		
		return [[NSString alloc] initWithBytesNoCopy:subStr
		                                      length:subLen
		                                    encoding:NSUTF8StringEncoding
		                                freeWhenDone:NO];
	}
}

@end

//
//  iTermProcessCache.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 7/18/18.
//

#import <Cocoa/Cocoa.h>

#import "iTermLSOF.h"
#import "iTermProcessCache.h"
#import "iTermRateLimitedUpdate.h"
#import "NSArray+iTerm.h"
#import <stdatomic.h>

@interface iTermProcessCache()
@property (atomic) BOOL needsUpdateFlag;

// Maps process id to deepest foreground job. Shared between main thread and _queue
@property (atomic) NSDictionary<NSNumber *, iTermProcessInfo *> *cachedDeepestForegroundJob;

@end

@implementation iTermProcessCache {
    dispatch_queue_t _queue;
    iTermProcessCollection *_collection; // _queue
    _Atomic bool _needsUpdate;
    NSMutableSet<NSNumber *> *_trackedPids;  // _queue
    iTermRateLimitedUpdate *_rateLimit;  // keeps updateIfNeeded from eating all the CPU
}

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static id instance;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.iterm2.process-cache", DISPATCH_QUEUE_SERIAL);
        _rateLimit = [[iTermRateLimitedUpdate alloc] init];
        _rateLimit.minimumInterval = 0.5;
        _trackedPids = [NSMutableSet set];
        [self setNeedsUpdate:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:NSApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidResignActive:)
                                                     name:NSApplicationDidResignActiveNotification
                                                   object:nil];
    }
    return self;
}

#pragma mark - APIs

- (void)setNeedsUpdate:(BOOL)needsUpdate {
    self.needsUpdateFlag = needsUpdate;
    if (needsUpdate) {
        [_rateLimit performRateLimitedSelector:@selector(updateIfNeeded) onTarget:self withObject:nil];
    }
}

- (iTermProcessInfo *)processInfoForPid:(pid_t)pid {
    __block iTermProcessInfo *info = nil;
    dispatch_sync(_queue, ^{
        info = [self->_collection infoForProcessID:pid];
    });
    return info;
}

- (iTermProcessInfo *)deepestForegroundJobForPid:(pid_t)pid {
    NSDictionary<NSNumber *, iTermProcessInfo *> *cache = self.cachedDeepestForegroundJob;
    return cache[@(pid)];
}

- (void)registerTrackedPID:(pid_t)pid {
    dispatch_async(_queue, ^{
        [self->_trackedPids addObject:@(pid)];
    });
}

- (void)unregisterTrackedPID:(pid_t)pid {
    dispatch_async(_queue, ^{
        [self->_trackedPids removeObject:@(pid)];
    });
}

#pragma mark - Private

- (void)updateIfNeeded {
    if (!self.needsUpdateFlag) {
        return;
    }

    NSArray<NSNumber *> *allPids = [iTermLSOF allPids];

    // pid -> ppid
    NSMutableDictionary<NSNumber *, NSNumber *> *parentmap = [NSMutableDictionary dictionary];
    iTermProcessCollection *collection = [[iTermProcessCollection alloc] init];
    for (NSNumber *pidNumber in allPids) {
        pid_t pid = pidNumber.intValue;

        pid_t ppid = [iTermLSOF ppidForPid:pid];
        if (!ppid) {
            continue;
        }

        parentmap[@(pid)] = @(ppid);
        [collection addProcessWithProcessID:pid parentProcessID:ppid];
    }

    [collection commit];

    NSMutableDictionary<NSNumber *, iTermProcessInfo *> *cache = [NSMutableDictionary dictionary];
    for (NSNumber *root in _trackedPids) {
        iTermProcessInfo *info = [collection infoForProcessID:root.integerValue].deepestForegroundJob;
        if (info) {
            cache[root] = info;
        }
    }
    self.cachedDeepestForegroundJob = cache;
    
    _collection = collection;
    self.needsUpdateFlag = NO;
}

#pragma mark - Notifications

- (void)applicationDidResignActive:(NSNotification *)notification {
    _rateLimit.minimumInterval = 5;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    _rateLimit.minimumInterval = 0.5;
}

@end

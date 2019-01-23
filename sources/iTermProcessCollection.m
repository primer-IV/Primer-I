//
//  iTermProcessCollection.m
//  iTerm2
//
//  Created by George Nachman on 4/30/17.
//
//

#import "iTermLSOF.h"
#import "iTermProcessCollection.h"
#import "NSArray+iTerm.h"

@interface iTermProcessInfo()
@property(nonatomic, weak, readwrite) iTermProcessInfo *parent;
@property(atomic, strong) NSString *nameValue;
@property(atomic) NSNumber *isForegroundJobValue;
@end

@implementation iTermProcessInfo {
    NSMutableArray<iTermProcessInfo *> *_children;
    __weak iTermProcessInfo *_deepestForegroundJob;
    BOOL _haveDeepestForegroundJob;
    NSString *_name;
    NSNumber *_isForegroundJob;
    dispatch_once_t _once;
    NSNumber *_testValueForForegroundJob;
}

- (instancetype)initWithPid:(pid_t)processID
                       ppid:(pid_t)parentProcessID {
    self = [super init];
    if (self) {
        _processID = processID;
        _parentProcessID = parentProcessID;
    }
    return self;
}

- (NSString *)treeStringWithIndent:(NSString *)indent {
    NSString *children = [[_children mapWithBlock:^id(id anObject) {
        return [anObject treeStringWithIndent:[indent stringByAppendingString:@"  "]];
    }] componentsJoinedByString:@"\n"];
    if (_children.count > 0) {
        children = [@"\n" stringByAppendingString:children];
    }
    return [NSString stringWithFormat:@"%@pid=%@ name=%@ fg=%@%@", indent, @(self.processID), self.name, @(self.isForegroundJob), children];
}

- (NSMutableArray<iTermProcessInfo *> *)children {
    if (!_children) {
        _children = [NSMutableArray array];
    }
    return _children;
}

- (iTermProcessInfo *)deepestForegroundJob {
    if (!_haveDeepestForegroundJob) {
        NSInteger level = 0;
        NSMutableSet<NSNumber *> *visitedPids = [NSMutableSet set];
        BOOL cycle = NO;
        return [self deepestForegroundJob:&level visited:visitedPids cycle:&cycle depth:0];
    }
    return _deepestForegroundJob;
}

- (iTermProcessInfo *)deepestForegroundJob:(NSInteger *)levelInOut visited:(NSMutableSet *)visited cycle:(BOOL *)cycle depth:(NSInteger)depth {
    if (depth > 50 || [visited containsObject:@(self.processID)]) {
        _haveDeepestForegroundJob = YES;
        _deepestForegroundJob = nil;
        *cycle = YES;
        return nil;
    } else {
        [visited addObject:@(self.processID)];
    }

    NSInteger bestLevel = *levelInOut;
    iTermProcessInfo *bestProcessInfo = nil;

    if (_children.count == 0 && self.isForegroundJob) {
        _haveDeepestForegroundJob = YES;
        _deepestForegroundJob = self;
        return self;
    } else if (self.isForegroundJob) {
        bestProcessInfo = self;
    }

    for (iTermProcessInfo *child in _children) {
        NSInteger level = *levelInOut + 1;
        iTermProcessInfo *candidate = [child deepestForegroundJob:&level visited:visited cycle:cycle depth:depth + 1];
        if (*cycle) {
            _haveDeepestForegroundJob = YES;
            _deepestForegroundJob = nil;
            return nil;
        }
        if (candidate) {
            if (level > bestLevel || bestProcessInfo == nil) {
                bestLevel = level;
                bestProcessInfo = candidate;
            }
        }
    }
    _haveDeepestForegroundJob = YES;
    _deepestForegroundJob = bestProcessInfo;
    *levelInOut = bestLevel;
    return bestProcessInfo;
}

- (NSArray<iTermProcessInfo *> *)flattenedTree {
    NSArray *flat = [_children flatMapWithBlock:^id(iTermProcessInfo *child) {
        return child.flattenedTree;
    }];
    if (flat.count) {
        return [@[ self ] arrayByAddingObjectsFromArray:flat];
    } else {
        return @[ self ];
    }
}

- (void)doSlowLookup {
    dispatch_once(&_once, ^{
        BOOL fg;
        self.nameValue = [iTermLSOF nameOfProcessWithPid:self->_processID isForeground:&fg];
        self.isForegroundJobValue = @(fg);
    });
}

- (NSString *)name {
    [self doSlowLookup];
    return self.nameValue;
}

- (BOOL)isForegroundJob {
    if (_testValueForForegroundJob) {
        return [_testValueForForegroundJob boolValue];
    }
    [self doSlowLookup];
    return self.isForegroundJobValue.boolValue;
}

- (void)resolveAsynchronously {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.iterm2.pid-lookup", DISPATCH_QUEUE_SERIAL);
    });
    dispatch_async(queue, ^{
        [self doSlowLookup];
    });
}

- (void)privateSetIsForegroundJob {
    _testValueForForegroundJob = @YES;
}

@end

@implementation iTermProcessCollection {
    NSMutableDictionary<NSNumber *, iTermProcessInfo *> *_processes;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _processes = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSString *)treeString {
    return [[_processes.allValues mapWithBlock:^id(iTermProcessInfo *anObject) {
        return [anObject treeStringWithIndent:@""];
    }] componentsJoinedByString:@"\n"];
}

- (iTermProcessInfo *)addProcessWithProcessID:(pid_t)processID
                              parentProcessID:(pid_t)parentProcessID {
    iTermProcessInfo *info = [[iTermProcessInfo alloc] initWithPid:processID
                                                              ppid:parentProcessID];
    _processes[@(processID)] = info;
    return info;
}

- (void)commit {
    [_processes enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull processID, iTermProcessInfo * _Nonnull info, BOOL * _Nonnull stop) {
        info.parent = self->_processes[@(info.parentProcessID)];
        [info.parent.children addObject:info];
    }];
}

- (iTermProcessInfo *)infoForProcessID:(pid_t)processID {
    return _processes[@(processID)];
}

@end

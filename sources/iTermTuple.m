//
//  iTermTuple.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 1/9/18.
//

#import "iTermTuple.h"

#import "NSArray+iTerm.h"
#import "NSObject+iTerm.h"

static NSString *const iTermTupleValueKey = @"value";

// https://www.mikeash.com/pyblog/friday-qa-2010-06-18-implementing-equality-and-hashing.html
// NOTE: This does not compose well. Use iTermCombineHash if you need to chain hashes.
static NSUInteger iTermMikeAshHash(NSUInteger hash1, NSUInteger hash2) {
    static const int rot = (CHAR_BIT * sizeof(NSUInteger)) / 2;
    return hash1 ^ ((hash2 << rot) | (hash2 >> rot));
}

// http://www.cse.yorku.ca/~oz/hash.html
static NSUInteger iTermDJB2Hash(unsigned char *bytes, size_t length) {
    NSUInteger hash = 5381;

    for (NSUInteger i = 0; i < length; i++) {
        unichar c = bytes[i];
        hash = (hash * 33) ^ c;
    }

    return hash;
}

static NSUInteger iTermCombineHash(NSUInteger hash1, NSUInteger hash2) {
    unsigned char hash1Bytes[sizeof(NSUInteger)];
    memmove(hash1Bytes, &hash1, sizeof(hash1));
    return iTermMikeAshHash(hash2, iTermDJB2Hash(hash1Bytes, sizeof(hash1)));
}


@implementation iTermTuple

+ (instancetype)tupleWithObject:(id)firstObject andObject:(id)secondObject {
    iTermTuple *tuple = [[self alloc] init];
    tuple.firstObject = firstObject;
    tuple.secondObject = secondObject;
    return tuple;
}

+ (instancetype)fromPlistValue:(id)plistValue {
    NSArray *array = [NSArray castFrom:plistValue];
    NSDictionary *firstDict = [array uncheckedObjectAtIndex:0] ?: @{};
    NSDictionary *secondDict = [array uncheckedObjectAtIndex:1] ?: @{};
    return [iTermTuple tupleWithObject:firstDict[iTermTupleValueKey]
                             andObject:secondDict[iTermTupleValueKey]];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _firstObject = [aDecoder decodeObjectForKey:@"firstObject"];
        _secondObject = [aDecoder decodeObjectForKey:@"secondObject"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_firstObject forKey:@"firstObject"];
    [aCoder encodeObject:_secondObject forKey:@"secondObject"];
}

- (id)plistValue {
    NSDictionary *first = self.firstObject ? @{ iTermTupleValueKey: self.firstObject } : @{};
    NSDictionary *second = self.secondObject ? @{ iTermTupleValueKey: self.secondObject } : @{};
    return @[ first, second ];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p (%@, %@)>",
            NSStringFromClass([self class]),
            self,
            _firstObject,
            _secondObject];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    iTermTuple *other = object;
    return ((_firstObject == other->_firstObject || [_firstObject isEqual:other->_firstObject]) &&
            (_secondObject == other->_secondObject || [_secondObject isEqual:other->_secondObject]));
}

- (id)copyWithZone:(NSZone *)zone {
    return [[self class] tupleWithObject:_firstObject andObject:_secondObject];
}

- (NSUInteger)hash {
    return iTermMikeAshHash([_firstObject hash],
                            [_secondObject hash]);
}

@end

@implementation iTermTriple

+ (instancetype)tripleWithObject:(id)firstObject andObject:(id)secondObject object:(id)thirdObject {
    iTermTriple *triple = [super tupleWithObject:firstObject andObject:secondObject];
    triple->_thirdObject = thirdObject;
    return triple;
}

+ (instancetype)fromPlistValue:(id)plistValue {
    NSArray *array = [NSArray castFrom:plistValue];
    NSDictionary *firstDict = [array uncheckedObjectAtIndex:0] ?: @{};
    NSDictionary *secondDict = [array uncheckedObjectAtIndex:1] ?: @{};
    NSDictionary *thirdDict = [array uncheckedObjectAtIndex:2] ?: @{};
    return [iTermTriple tripleWithObject:firstDict[iTermTupleValueKey]
                               andObject:secondDict[iTermTupleValueKey]
                                  object:thirdDict[iTermTupleValueKey]];
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _thirdObject = [aDecoder decodeObjectForKey:@"thirdObject"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_thirdObject forKey:@"thirdObject"];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p (%@, %@, %@)>",
            NSStringFromClass([self class]),
            self,
            self.firstObject,
            self.secondObject,
            _thirdObject];
}

- (id)plistValue {
    NSDictionary *first = self.firstObject ? @{ iTermTupleValueKey: self.firstObject } : @{};
    NSDictionary *second = self.secondObject ? @{ iTermTupleValueKey: self.secondObject } : @{};
    NSDictionary *third = self.thirdObject ? @{ iTermTupleValueKey: self.thirdObject } : @{};
    return @[ first, second, third ];
}

- (BOOL)isEqual:(id)object {
    if (![super isEqual:object]) {
        return NO;
    }
    iTermTriple *other = object;
    return (_thirdObject == other->_thirdObject || [_thirdObject isEqual:other->_thirdObject]);
}

- (id)copyWithZone:(NSZone *)zone {
    return [iTermTriple tripleWithObject:self.firstObject
                               andObject:self.secondObject
                                  object:_thirdObject];
}

- (NSUInteger)hash {
    return iTermCombineHash([super hash],
                            [_thirdObject hash]);
}

@end


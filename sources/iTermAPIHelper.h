//
//  iTermAPIHelper.h
//  iTerm2SharedARC
//
//  Created by George Nachman on 4/18/18.
//

#import <Foundation/Foundation.h>
#import "iTermAPIServer.h"
#import "iTermTuple.h"

extern NSString *const iTermRemoveAPIServerSubscriptionsNotification;
extern NSString *const iTermAPIRegisteredFunctionsDidChangeNotification;
extern NSString *const iTermAPIDidRegisterSessionTitleFunctionNotification;

extern const NSInteger iTermAPIHelperFunctionCallUnregisteredErrorCode;
extern const NSInteger iTermAPIHelperFunctionCallOtherErrorCode;
extern NSString *const iTermAPIHelperFunctionCallErrorUserInfoKeyConnection;

typedef void (^iTermServerOriginatedRPCCompletionBlock)(id, NSError *);

@interface iTermAPIHelper : NSObject<iTermAPIServerDelegate>

+ (instancetype)sharedInstance;

+ (NSString *)invocationWithName:(NSString *)name
                        defaults:(NSArray<ITMRPCRegistrationRequest_RPCArgument*> *)defaultsArray;

- (instancetype)init NS_UNAVAILABLE;

- (void)postAPINotification:(ITMNotification *)notification toConnectionKey:(NSString *)connectionKey;

- (void)dispatchRPCWithName:(NSString *)name
                  arguments:(NSDictionary *)arguments
                 completion:(iTermServerOriginatedRPCCompletionBlock)completion;

// function name -> [ arg1, arg2, ... ]
+ (NSDictionary<NSString *, NSArray<NSString *> *> *)registeredFunctionSignatureDictionary;

// Tuple is (display name, invocation).
+ (NSArray<iTermTuple<NSString *, NSString *> *> *)sessionTitleFunctions;

+ (NSArray<ITMRPCRegistrationRequest *> *)statusBarComponentProviderRegistrationRequests;

// Performs block either when the function becomes registered, immediately if it's already
// registered, or after timeout (with an argument of YES) if it does not become registered
// soon enough.
- (void)performBlockWhenFunctionRegisteredWithName:(NSString *)name
                                         arguments:(NSArray<NSString *> *)arguments
                                           timeout:(NSTimeInterval)timeout
                                             block:(void (^)(BOOL timedOut))block;

// stringSignature is like func(arg1,arg2). Use iTermFunctionSignatureFromNameAndArguments to construct it safely.
- (BOOL)haveRegisteredFunctionWithSignature:(NSString *)stringSignature;
- (NSString *)connectionKeyForRPCWithSignature:(NSString *)signature;

@end

//
//  AAReachability.m
//  AAReachability
//
//  Created by Aaron Feng on 2022/11/7.
//

#import "AAReachability.h"
#import <stdatomic.h>
#import <netinet/in.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface AAReachability ()
- (void)updateReachabilityFlags:(SCNetworkReachabilityFlags)flags;
@end

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
    AAReachability *noteObject = (__bridge AAReachability *)info;
    if ([noteObject isKindOfClass:AAReachability.class]) {
        [noteObject updateReachabilityFlags:flags];
    }
}

@implementation AAReachability {
    dispatch_queue_t _queue;
    void *_specificKey;
    
    SCNetworkReachabilityRef _reachabilityRef;
    CTTelephonyNetworkInfo *_networkInfo;
    atomic_uint _currentReachabilityStatus;
}

#pragma mark - init

+ (instancetype)sharedInstance {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("com.queue.AAReachability", DISPATCH_QUEUE_SERIAL);
        _specificKey = &_specificKey;
        void *nonNullPointer = (__bridge void *)self;
        dispatch_queue_set_specific(_queue, _specificKey, nonNullPointer, nil);
        
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        _reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *) &zeroAddress);
        _networkInfo = [CTTelephonyNetworkInfo new];
        
        // add notification observer
        [self startNotifier];
        if (@available(iOS 12.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(radioAccessChanged:) name:CTServiceRadioAccessTechnologyDidChangeNotification object:nil];
        } else {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(radioAccessChanged:) name:CTRadioAccessTechnologyDidChangeNotification object:nil];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshReachabilityStatus) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        // initial status
        _currentReachabilityStatus = AANetworkStatusOffline;
        dispatch_sync(_queue, ^{
            [self refreshReachabilityStatus];
        });
    }
    return self;
}

- (CTTelephonyNetworkInfo *)telephonyNetworkInfo {
    return _networkInfo;
}

+ (CTTelephonyNetworkInfo *)sharedTelephonyNetworkInfo {
    return [self sharedInstance]->_networkInfo;
}

#pragma mark - dealloc
- (void)dealloc {
    [self stopNotifier];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (_reachabilityRef != NULL) {
        CFRelease(_reachabilityRef);
    }
}

- (void)runInQueue:(dispatch_block_t)block {
    if (dispatch_get_specific(_specificKey)) {
        block();
        return;
    }
    dispatch_async(_queue, block);
}

#pragma mark - Start and stop notifier

- (BOOL)startNotifier {
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes)) {
            return YES;
        }
    }
    return NO;
}

- (void)stopNotifier {
    if (_reachabilityRef != NULL) {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    }
}

#pragma mark - update status
- (AANetworkStatus)currentReachabilityStatus {
    return _currentReachabilityStatus;
}

+ (AANetworkStatus)currentReachabilityStatus {
    return [[self sharedInstance] currentReachabilityStatus];
}

- (void)updateCurrentReachabilityStatus:(AANetworkStatus)status {
    if (_currentReachabilityStatus == status) {
        return;
    }
    _currentReachabilityStatus = status;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName: AAReachabilityNetworkChangedNotification object: weakSelf];
    });
}

- (void)updateReachabilityFlags:(SCNetworkReachabilityFlags)flags {
    [self runInQueue:^{
        if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
            [self updateCurrentReachabilityStatus:AANetworkStatusOffline];
            return;
        }
        
        if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
            [self updateCurrentReachabilityStatus:AANetworkStatusWifi];
            return;
        }
        
        if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
            (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
            if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
                [self updateCurrentReachabilityStatus:AANetworkStatusWifi];
                return;
            }
        }
        
        if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
            [self updateRadioAccess:nil];
            return;
        }
        
        [self updateCurrentReachabilityStatus:AANetworkStatusOffline];
    }];
}

- (void)updateRadioAccess:(NSString *)identifier {
    [self runInQueue:^{
        NSString *radioAccess = nil;
        if (@available(iOS 12.0, *)) {
            NSDictionary *dic = [self->_networkInfo.serviceCurrentRadioAccessTechnology copy];
            NSString *key = [identifier copy];
            if (key.length <= 0) {
                if (@available(iOS 13.0, *)) {
                    key = self->_networkInfo.dataServiceIdentifier;
                }
            }
            if (key.length > 0) {
                radioAccess = [dic objectForKey:key];
            }
            if (radioAccess.length <= 0) {
                radioAccess = [dic.allValues firstObject];
            }
        } else {
            radioAccess = [self->_networkInfo.currentRadioAccessTechnology copy];
        }
        
        if (radioAccess.length > 0) {
            return;
        }
        
        if (@available(iOS 14.1, *)) {
            if ([radioAccess isEqualToString:CTRadioAccessTechnologyNR] ||
                [radioAccess isEqualToString:CTRadioAccessTechnologyNRNSA]) {
                [self updateCurrentReachabilityStatus:AANetworkStatus5G];
                return;
            }
        }
        if ([radioAccess isEqualToString:CTRadioAccessTechnologyLTE]) {
            [self updateCurrentReachabilityStatus:AANetworkStatus4G];
            return;
        }
        if ([radioAccess isEqualToString:CTRadioAccessTechnologyHSDPA] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyWCDMA] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyHSUPA] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyeHRPD]) {
            [self updateCurrentReachabilityStatus:AANetworkStatus3G];
            return;
        }
        if ([radioAccess isEqualToString:CTRadioAccessTechnologyGPRS] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyEdge] ||
            [radioAccess isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
            [self updateCurrentReachabilityStatus:AANetworkStatus2G];
            return;
        }
    }];
}

- (void)radioAccessChanged:(NSNotification *)notification {
    [self runInQueue:^{
        [self updateRadioAccess: [notification.object isKindOfClass:NSString.class] ? notification.object : nil];
    }];
}

- (void)refreshReachabilityStatus {
    [self runInQueue:^{
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self->_reachabilityRef, &flags)) {
            [self updateReachabilityFlags:flags];
        }
    }];
}

@end

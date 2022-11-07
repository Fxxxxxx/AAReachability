//
//  AAReachability.m
//  AAReachability
//
//  Created by Aaron Feng on 2022/11/7.
//

#import "AAReachability.h"
#import <netinet/in.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>


@interface AAReachability ()
- (BOOL)updateCurrentReachabilityStatus;
@end

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
#pragma unused (target, flags)
    NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
    NSCAssert([(__bridge NSObject*) info isKindOfClass: [AAReachability class]], @"info was wrong class in ReachabilityCallback");

    AAReachability* noteObject = (__bridge AAReachability *)info;
    // Post a notification to notify the client that the network reachability changed.
    if ([noteObject updateCurrentReachabilityStatus]) {
        [[NSNotificationCenter defaultCenter] postNotificationName: AAReachabilityNetworkChangedNotification object: noteObject];
    }
}

@implementation AAReachability {
    SCNetworkReachabilityRef _reachabilityRef;
    AANetworkStatus _currentReachabilityStatus;
    dispatch_semaphore_t _statusSemaphore;
}

+ (instancetype)reachabilityWithHostName:(NSString *)hostName {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
    return [[self alloc] initWithRef:reachability];
}


+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress);
    return [[self alloc] initWithRef:reachability];
}

- (instancetype)initWithRef:(SCNetworkReachabilityRef)ref {
    if (ref == NULL) {
        return NULL;
    }
    self = [super init];
    if (self) {
        _reachabilityRef = ref;
        _statusSemaphore = dispatch_semaphore_create(1);
        [self updateCurrentReachabilityStatus];
        if (![self startNotifier]) {
            [self startNotifier];
        }
    } else {
        CFRelease(ref);
    }
    return self;
}

+ (instancetype)reachabilityForInternetConnection {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    static dispatch_once_t onceToken;
    static id instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [self reachabilityWithAddress: (const struct sockaddr *) &zeroAddress];
    });
    return instance;
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

- (void)dealloc {
    [self stopNotifier];
    if (_reachabilityRef != NULL) {
        CFRelease(_reachabilityRef);
    }
}


- (AANetworkStatus)currentReachabilityStatus {
    AANetworkStatus result;
    dispatch_semaphore_wait(_statusSemaphore, DISPATCH_TIME_FOREVER);
    result = _currentReachabilityStatus;
    dispatch_semaphore_signal(_statusSemaphore);
    return result;
}

- (BOOL)updateCurrentReachabilityStatus {
    NSAssert(_reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
    SCNetworkReachabilityFlags flags;
    if (!SCNetworkReachabilityGetFlags(_reachabilityRef, &flags)) {
        return NO;
    }
    AANetworkStatus status = [self networkStatusForFlags:flags];
    BOOL isChanged = NO;
    dispatch_semaphore_wait(_statusSemaphore, DISPATCH_TIME_FOREVER);
    isChanged = _currentReachabilityStatus != status;
    _currentReachabilityStatus = status;
    dispatch_semaphore_signal(_statusSemaphore);
    return isChanged;
}

- (AANetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags {
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        // The target host is not reachable.
        return AANetworkStatusOffline;
    }

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        return AANetworkStatusWifi;
    }

    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
        (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            /*
             ... and no [user] intervention is needed...
             */
            return AANetworkStatusWifi;
        }
    }

    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        return [self getCurrentWwanStatus];
    }
    
    return AANetworkStatusOffline;
}

- (AANetworkStatus)getCurrentWwanStatus {
    static dispatch_once_t onceToken;
    static CTTelephonyNetworkInfo *info = nil;
    dispatch_once(&onceToken, ^{
        info = [[CTTelephonyNetworkInfo alloc] init];
    });
    
    NSString *status = nil;
    if (@available(iOS 12.0, *)) {
        NSDictionary *dic = [info.serviceCurrentRadioAccessTechnology copy];
        status = [dic allValues].firstObject;
    } else {
        status = info.currentRadioAccessTechnology;
    }
    
    if (![status isKindOfClass:NSString.class] ||
        status.length <= 0) {
        return AANetworkStatus4G;
    }
    
    if ([status isEqualToString:CTRadioAccessTechnologyGPRS] ||
        [status isEqualToString:CTRadioAccessTechnologyEdge] ||
        [status isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
        return AANetworkStatus2G;
    }
    if ([status isEqualToString:CTRadioAccessTechnologyHSDPA] ||
        [status isEqualToString:CTRadioAccessTechnologyWCDMA] ||
        [status isEqualToString:CTRadioAccessTechnologyHSUPA] ||
        [status isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0] ||
        [status isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA] ||
        [status isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB] ||
        [status isEqualToString:CTRadioAccessTechnologyeHRPD]) {
        return AANetworkStatus3G;
    }
    if ([status isEqualToString:CTRadioAccessTechnologyLTE]) {
        return AANetworkStatus4G;
    }
    if (@available(iOS 14.1, *)) {
        if ([status isEqualToString:CTRadioAccessTechnologyNR] ||
            [status isEqualToString:CTRadioAccessTechnologyNRNSA]) {
            return AANetworkStatus5G;
        }
    }
    
    return AANetworkStatus4G;
}

@end

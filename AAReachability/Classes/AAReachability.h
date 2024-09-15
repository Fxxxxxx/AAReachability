//
//  AAReachability.h
//  AAReachability
//
//  Created by Aaron Feng on 2022/11/7.
//

#import <Foundation/Foundation.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AANetworkStatus) {
    AANetworkStatusOffline = 0,
    AANetworkStatusWifi = 1,
    AANetworkStatus2G = 2,
    AANetworkStatus3G = 3,
    AANetworkStatus4G = 4,
    AANetworkStatus5G = 5
};

#define AAReachabilityNetworkChangedNotification @"AAReachabilityNetworkChangedNotification"

#define AAReachabilityCurrentStatus [[AAReachability sharedInstance] currentReachabilityStatus]

@interface AAReachability : NSObject

+ (instancetype)sharedInstance;

- (AANetworkStatus)currentReachabilityStatus;
+ (AANetworkStatus)currentReachabilityStatus;

- (CTTelephonyNetworkInfo *)telephonyNetworkInfo;
+ (CTTelephonyNetworkInfo *)sharedTelephonyNetworkInfo;

@end

NS_ASSUME_NONNULL_END

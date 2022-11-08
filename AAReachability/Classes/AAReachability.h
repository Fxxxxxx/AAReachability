//
//  AAReachability.h
//  AAReachability
//
//  Created by Aaron Feng on 2022/11/7.
//

#import <Foundation/Foundation.h>

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

#define AAReachabilityCurrentStatus [[AAReachability reachabilityForInternetConnection] currentReachabilityStatus]

@interface AAReachability : NSObject

/*!
 * Use to check the reachability of a given host name.
 */
+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*!
 * Use to check the reachability of a given IP address.
 */
+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress;

/*!
 * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
 */
+ (instancetype)reachabilityForInternetConnection;

/*!
 * WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
 */
- (BOOL)connectionRequired;

/// 当前网络状态，实际为缓存值，非耗时操作
- (AANetworkStatus)currentReachabilityStatus;

/// 初始化，APP启动时调用，子线程预热
+ (void)setup;

@end

NS_ASSUME_NONNULL_END

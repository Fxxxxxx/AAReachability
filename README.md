# AAReachability

[![CI Status](https://img.shields.io/travis/AaronFeng/AAReachability.svg?style=flat)](https://travis-ci.org/AaronFeng/AAReachability)
[![Version](https://img.shields.io/cocoapods/v/AAReachability.svg?style=flat)](https://cocoapods.org/pods/AAReachability)
[![License](https://img.shields.io/cocoapods/l/AAReachability.svg?style=flat)](https://cocoapods.org/pods/AAReachability)
[![Platform](https://img.shields.io/cocoapods/p/AAReachability.svg?style=flat)](https://cocoapods.org/pods/AAReachability)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

```

// the network status define
typedef NS_ENUM(NSUInteger, AANetworkStatus) {
    AANetworkStatusOffline = 0,
    AANetworkStatusWifi = 1,
    AANetworkStatus2G = 2,
    AANetworkStatus3G = 3,
    AANetworkStatus4G = 4,
    AANetworkStatus5G = 5
};

// usage example
AANetworkStatus status = [[AAReachability sharedInstance] currentReachabilityStatus];


```

## Requirements

## Installation

AAReachability is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'AAReachability'
```

## Author

AaronFeng, fengjiang04@meituan.com

## License

AAReachability is available under the MIT license. See the LICENSE file for more info.

//
//  AAViewController.m
//  AAReachability
//
//  Created by AaronFeng on 11/07/2022.
//  Copyright (c) 2022 AaronFeng. All rights reserved.
//

#import "AAViewController.h"
@import AAReachability;

@interface AAViewController ()

@end

@implementation AAViewController

- (void)viewDidLoad
{
[super viewDidLoad];
// Do any additional setup after loading the view, typically from a nib.

for (NSUInteger i = 0; i < 100; i++) {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTimeInterval interval = CACurrentMediaTime();
        if (@available(iOS 12.0, *)) {
            AANetworkType status = AAReachability.shared.networkType;
            interval = CACurrentMediaTime() - interval;
            NSLog(@"%ld, %.2f ms", status, interval * 1000);
        }
        });
    }
                   
                   if (@available(iOS 12.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserverForName:AAReachability.AAReachabilityNetworkChangedNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            NSLog(@"network changed: %lu", AAReachability.shared.networkType);
        }];
    }
                   
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

//
//  AAReachability.swift
//  AAReachability
//
//  Created by Aaron Feng on 2024/11/1.
//

import Foundation
import Network
import CoreTelephony

@objc
public enum AANetworkType: Int {
    case unknown = -1
    case offline = 0
    case wifi = 1
    case wiredEthernet = 2
    case loopback = 3
    case cellular = 10
    case cellular2G = 11
    case cellular3G = 12
    case cellular4G = 13
    case cellular5G = 14
}

@available(iOS 12.0, *)
@objcMembers
final public class AAReachability: NSObject {
    
    public static let AAReachabilityNetworkChangedNotification = "AAReachabilityNetworkChangedNotification"
    
    private let pathMonitor: NWPathMonitor
    private let networkInfo: CTTelephonyNetworkInfo
    private let queue: DispatchQueue
    
    private var _networkType = AANetworkType.unknown
    public var networkType: AANetworkType {
        _networkType
    }
    
    public static let shared = {
        let ins = AAReachability()
        ins.start()
        return ins
    } ()
    
    public override init() {
        queue = DispatchQueue(label: "queue.reachability.aa")
        networkInfo = CTTelephonyNetworkInfo()
        pathMonitor = NWPathMonitor()
    }
    
    public func start() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.pathUpdate(path)
        }
        pathMonitor.start(queue: queue)
    }
    
    public func cancel() {
        pathMonitor.cancel()
    }
    
    func pathUpdate(_ path: NWPath) -> Void {
        let newType: AANetworkType = {
            if path.status != .satisfied {
                return .offline
            }
            if path.usesInterfaceType(.wifi) {
                return .wifi
            }
            if path.usesInterfaceType(.wiredEthernet) {
                return .wiredEthernet
            }
            if path.usesInterfaceType(.loopback) {
                return .loopback
            }
            if path.usesInterfaceType(.cellular) {
                return currentCellularType()
            }
            return .unknown
        } ()
        if newType == _networkType {
            return
        }
        _networkType = newType
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .init(AAReachability.AAReachabilityNetworkChangedNotification), object: nil, userInfo: [
                "networkType": newType
            ])
        }
    }
    
    func currentCellularType() -> AANetworkType {
        guard let raTech = currentRadioAccessTechnology() else { return .cellular }
        if #available(iOS 14.1, *) {
            if raTech == CTRadioAccessTechnologyNR ||
                raTech == CTRadioAccessTechnologyNRNSA {
                return .cellular5G
            }
        }
        switch raTech {
        case CTRadioAccessTechnologyLTE:
            return .cellular4G
        case CTRadioAccessTechnologyHSDPA,
            CTRadioAccessTechnologyWCDMA,
            CTRadioAccessTechnologyHSUPA,
            CTRadioAccessTechnologyCDMAEVDORev0,
            CTRadioAccessTechnologyCDMAEVDORevA,
            CTRadioAccessTechnologyCDMAEVDORevB,
        CTRadioAccessTechnologyeHRPD:
            return .cellular3G
        case CTRadioAccessTechnologyGPRS,
            CTRadioAccessTechnologyEdge,
        CTRadioAccessTechnologyCDMA1x:
            return .cellular2G
        default:
            return .cellular
        }
    }
    
    public func currentRadioAccessTechnology() -> String? {
        if #available(iOS 13.0, *) {
            if let key = networkInfo.dataServiceIdentifier {
                return networkInfo.serviceCurrentRadioAccessTechnology?[key] ?? networkInfo.currentRadioAccessTechnology
            }
        }
        return networkInfo.currentRadioAccessTechnology
    }
    
}

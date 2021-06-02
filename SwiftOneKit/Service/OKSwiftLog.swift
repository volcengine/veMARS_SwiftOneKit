//
//  OKSwiftLog.swift
//  SwiftOneKit
//
//  Created by bob on 2021/1/15.
//

import Foundation
import OneKit

public class OKSwiftLog {
    public static func verbose(_ tag: String,
                               _ log: String,
                               file:String = #file,
                               line:Int = #line) {
        if let service = OKServiceCenter.sharedInstance().service(for: OKLogService.self) as? OKLogService {
            let fileName = (file as NSString).lastPathComponent
            service.verbose("[\(tag)][\(fileName):\(line)]" + log)
        }
    }
    
    public static func debug(_ tag: String,
                             _ log: String,
                             file:String = #file,
                             line:Int = #line) {
        if let service = OKServiceCenter.sharedInstance().service(for: OKLogService.self) as? OKLogService {
            let fileName = (file as NSString).lastPathComponent
            service.debug("[\(tag)][\(fileName):\(line)]" + log)
        }
    }
    
    public static func info(_ tag: String,
                            _ log: String,
                            file:String = #file,
                            line:Int = #line) {
        if let service = OKServiceCenter.sharedInstance().service(for: OKLogService.self) as? OKLogService {
            let fileName = (file as NSString).lastPathComponent
            service.info("[\(tag)][\(fileName):\(line)]" + log)
        }
    }
    
    public static func warn(_ tag: String,
                            _ log: String,
                            file:String = #file,
                            line:Int = #line) {
        if let service = OKServiceCenter.sharedInstance().service(for: OKLogService.self) as? OKLogService {
            let fileName = (file as NSString).lastPathComponent
            service.warn("[\(tag)][\(fileName):\(line)]" + log)
        }
    }
    
    public static func error(__ tag: String,
                             _ log: String,
                             file:String = #file,
                             line:Int = #line) {
        if let service = OKServiceCenter.sharedInstance().service(for: OKLogService.self) as? OKLogService {
            let fileName = (file as NSString).lastPathComponent
            service.error("[\(tag)][\(fileName):\(line)]" + log)
        }
    }
}

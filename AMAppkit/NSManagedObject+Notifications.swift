//
//  NSManagedObject+Notifications.swift
//  AMAppkit
//
//  Created by Ilya Kuznetsov on 11/29/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import CoreData

public extension NSManagedObject {

    @objc static func add(observer: AnyObject, closure: @escaping (AMNotification?)->()) {
        self.add(observer: observer, closure: closure, classes: [self])
    }
    
    @objc static func remove(observer: AnyObject) {
        self.remove(observer: observer, classes: [self])
    }
    
    @objc static func add(observer: AnyObject, closure: @escaping (AMNotification?)->(), classes: [NSManagedObject.Type]) {
        AMNotificationManager.shared.add(observer: observer, closure: closure, names: classNamesFor(classes: classes))
    }
    
    @objc static func remove(observer: AnyObject, classes: [NSManagedObject.Type]) {
        AMNotificationManager.shared.remove(observer: observer, names: classNamesFor(classes: classes))
    }
    
    @objc static func postUpdatesFor(classes: [NSManagedObject.Type], notification: AMNotification?) {
        AMNotificationManager.shared.postNotification(names: classNamesFor(classes: classes), notification: notification)
    }
    
    @objc private static func classNamesFor(classes: [NSManagedObject.Type]) -> [String] {
        return classes.map { String(describing: $0) }
    }
}

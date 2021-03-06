//
//  AMPagingCollectionHelper.swift
//  AMAppkit
//
//  Created by Ilya Kuznetsov on 11/29/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import UIKit

@objcMembers
open class AMPagingCollection: AMCollection {
    
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var yConstraint: NSLayoutConstraint?
    private var xConstraint: NSLayoutConstraint?
    
    open private(set) var loader: AMPagingLoader!
    private weak var pagingDelegate: AMPagingLoaderDelegate?
    
    override func setup() {
        super.setup()
        
        let loaderType = pagingDelegate!.pagingLoader?() ?? AMPagingLoader.self
        
        loader = loaderType.init(scrollView: collection,
                                 delegate: pagingDelegate!,
                                 addRefreshControl: { [unowned self] (control) in
                                        
                                    if #available(iOS 10.0, *) {
                                        self.collection.refreshControl = control
                                    } else {
                                        self.collection.insertSubview(control, at: 0)
                                    }
                                        
            }, scrollOnRefreshing: { [weak self] (control) in
                
                if let wSelf = self {
                    if wSelf.isVertical() {
                        wSelf.collection.contentOffset = CGPoint(x: 0, y: -control.bounds.size.width)
                    } else {
                        wSelf.collection.contentOffset = CGPoint(x: -control.bounds.size.width, y: 0)
                    }
                }
            }, setFooterVisible: { [weak self] (visible, footerView) in
                
                if let wSelf = self {
                    var insets = wSelf.collection.contentInset
                    
                    if visible {
                        wSelf.collection.addSubview(footerView)
                        if wSelf.isVertical() {
                            
                            footerView.translatesAutoresizingMaskIntoConstraints = false
                            
                            if wSelf.widthConstraint == nil {
                                wSelf.widthConstraint = NSLayoutConstraint(item: footerView,
                                                                     attribute: .width,
                                                                     relatedBy: .equal,
                                                                     toItem: wSelf.collection,
                                                                     attribute: .width,
                                                                     multiplier: 1.0,
                                                                     constant: 0)
                            }
                            wSelf.collection.addConstraint(wSelf.widthConstraint!)
                            
                            if wSelf.heightConstraint == nil {
                                wSelf.heightConstraint = NSLayoutConstraint(item: footerView,
                                                            attribute: .height,
                                                            relatedBy: .equal,
                                                            toItem: nil,
                                                            attribute: .notAnAttribute,
                                                            multiplier: 1.0,
                                                            constant: footerView.height)
                            }
                            footerView.addConstraint(wSelf.heightConstraint!)
                            
                            if wSelf.yConstraint == nil {
                                wSelf.yConstraint = NSLayoutConstraint(item: footerView,
                                                                           attribute: .top,
                                                                           relatedBy: .equal,
                                                                           toItem: wSelf.collection,
                                                                           attribute: .top,
                                                                           multiplier: 1.0,
                                                                           constant: 0)
                            }
                            wSelf.collection.addConstraint(wSelf.yConstraint!)
                            
                            if wSelf.xConstraint == nil {
                                wSelf.xConstraint = NSLayoutConstraint(item: footerView,
                                                                       attribute: .left,
                                                                       relatedBy: .equal,
                                                                       toItem: wSelf.collection,
                                                                       attribute: .left,
                                                                       multiplier: 1.0,
                                                                       constant: 0)
                            }
                            wSelf.collection.addConstraint(wSelf.xConstraint!)
                            
                            insets.bottom = footerView.frame.size.height
                        } else {
                            insets.right = footerView.frame.size.width
                        }
                    } else {
                        footerView.removeFromSuperview()
                        
                        if wSelf.isVertical() {
                            insets.bottom = 0
                        } else {
                            insets.right = 0
                        }
                    }
                    wSelf.collection.contentInset = insets
                    wSelf.reloadFooterPosition()
                }
        })
        collection.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    open func isVertical() -> Bool {
        return self.layout!.scrollDirection == .vertical
    }
    
    open func reloadFooterPosition() {
        let size = collection.contentSize
        
        if isVertical() {
            if let constraint = yConstraint {
                constraint.constant = size.height
            }
        } else {
            loader.footerLoadingView.center = CGPoint(x: size.width + loader.footerLoadingView.frame.size.width / 2.0, y: size.height / 2.0)
        }
    }
    
    public init(collection: AMCollectionView, pagingDelegate: CollectionDelegate & AMPagingLoaderDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(collection: collection, delegate: pagingDelegate)
    }
    
    public init(view: UIView, pagingDelegate: AMPagingLoaderDelegate & CollectionDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(view: view, delegate: pagingDelegate)
    }
    
    public init(customAdd: (AMCollectionView)->(), pagingDelegate: AMPagingLoaderDelegate & CollectionDelegate) {
        self.pagingDelegate = pagingDelegate
        super.init(customAdd: customAdd, delegate: pagingDelegate)
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if loader.footerLoadingView != nil, keyPath == "contentOffset", collection.superview != nil {
            reloadFooterPosition()
        }
    }
    
    deinit {
        collection.removeObserver(self, forKeyPath: "contentOffset")
    }
}

extension AMPagingCollection {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loader.endDecelerating()
        delegate?.scrollViewDidEndDecelerating?(scrollView)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loader.endDecelerating()
        }
        delegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
}

//
//  AMPagingLoader.swift
//  AMAppkit
//
//  Created by Ilya Kuznetsov on 11/26/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol AMPagingLoaderDelegate: class {
    
    @objc optional func hasRefreshControl() -> Bool
    
    @objc optional func shouldLoadMore() -> Bool
    
    @objc optional func pagingLoader() -> AMPagingLoader.Type?
    
    @objc optional func performOnRefresh()
    
    func reloadView(_ animated: Bool)
    
    func load(offset: Any?, completion: @escaping ([AnyHashable], Error?, /*new offset*/Any?)->())
}

@objc public protocol PCachable: class {
 
    func saveFirstPageInCache(objects: [AnyHashable])
    
    func loadFirstPageFromCache() -> [AnyHashable]
}

extension AMPagingLoaderDelegate {
    
    func cachable() -> PCachable? {
        return self as? PCachable
    }
}

@objcMembers
@objc open class AMPagingLoader: StaticSetupObject {
    
    open var processPullToRefreshError: ((AMPagingLoader, Error)->())! //AMAppearance Support
    open private(set) var refreshControl: UIRefreshControl?
    open var footerLoadingInset = CGSize(width: 0, height: 0)
    
    open var footerLoadingClass: AMFooterLoadingView.Type! {
        didSet {
            footerLoadingView = footerLoadingClass.loadFromNib()
            footerLoadingView.retry = { [unowned self] in
                self.loadMore()
            }
        }
    }
    open private(set) var footerLoadingView: AMFooterLoadingView!
    open private(set) var loading = false
    open private(set) weak var scrollView: UIScrollView!
    
    open var fetchedItems: [AnyHashable] = []
    open var offset: Any?
    
    private var currentOperationId: String?
    private weak var delegate: AMPagingLoaderDelegate!
    private var performedLoading = false
    private var shouldEndRefreshing = false
    private var shouldBeginRefreshing = false
    private var scrollOnRefreshing: (UIRefreshControl)->()
    private var setFooterVisible: (Bool, UIView)->()
    
    public required init(scrollView: UIScrollView,
         delegate: AMPagingLoaderDelegate,
         addRefreshControl: @escaping (UIRefreshControl)->(),
         scrollOnRefreshing: @escaping (UIRefreshControl)->(),
         setFooterVisible: @escaping (/*visible*/ Bool,/*footer*/ UIView)->()) {
        self.scrollView = scrollView
        self.delegate = delegate
        self.scrollOnRefreshing = scrollOnRefreshing
        self.setFooterVisible = setFooterVisible
        super.init()
        
        defer {
            self.footerLoadingClass = AMFooterLoadingView.self
        }
        
        if delegate.hasRefreshControl?() ?? true {
            refreshControl = AMRefreshControl()
            refreshControl?.addTarget(self, action: #selector(refreshAction), for: .valueChanged)
            addRefreshControl(refreshControl!)
        }
        self.fetchedItems = delegate.cachable()?.loadFirstPageFromCache() ?? []
        
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    @objc private func refreshAction() {
        shouldBeginRefreshing = true
    }
    
    // manually reload starting from the first page, usualy you should run this method in viewDidLoad or viewWillAppear
    open func refreshFromBeginning(showRefresh: Bool) {
        if let refreshControl = refreshControl, showRefresh {
            DispatchQueue.main.async {
                self.refresh(with: refreshControl)
            }
            scrollOnRefreshing(refreshControl)
        } else {
            refresh(with: nil)
        }
    }
    
    // load new page manually
    open func loadMore() {
        
        performedLoading = true
        footerLoadingView.state = .loading
        loading = true
        
        let operationId = UUID().uuidString
        currentOperationId = operationId
        
        delegate.load(offset: offset, completion: { [weak self] (objects, error, newOffset) in
            guard let wSelf = self else {
                return
            }
            if wSelf.currentOperationId != operationId {
                return
            }
            wSelf.loading = false
            if let error = error as NSError? {
                wSelf.footerLoadingView.state = error.code == NSURLErrorCancelled ? .stop : .failed
            } else {
                
                if objects.count > 0 && newOffset != nil {
                    wSelf.performedLoading = false
                }
                
                wSelf.offset = newOffset
                wSelf.append(items: objects, animated: false)
                
                if newOffset == nil {
                    UIView.animate(withDuration: objects.count > 0 ? 0 : 0.25, animations: {
                        if let view = wSelf.footerLoadingView {
                            wSelf.setFooterVisible(false, view)
                        }
                    })
                }
                wSelf.footerLoadingView.state = .stop
                
                if wSelf.offset != nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.loadModeIfNeeded()
                    }
                }
            }
        })
    }
    
    // append items to the end. customize adding items behaviour in subclass if needed
    open func append(items: [AnyHashable], animated: Bool) {
        var array = fetchedItems
        
        for object in items {
            if !array.contains(object) {
                array.append(object)
            }
        }
        fetchedItems = array
        
        let offset = scrollView.contentOffset
        delegate.reloadView(animated)
        scrollView.layoutIfNeeded()
        scrollView.contentOffset = offset
    }
    
    private func refresh(with refreshControl: UIRefreshControl?) {
        
        delegate.performOnRefresh?()
        
        loading = true
        setFooterVisible(true, footerLoadingView)
        footerLoadingView.state = .stop
        
        if let refreshControl = refreshControl {
            if !refreshControl.isRefreshing {
                refreshControl.beginRefreshing()
                scrollOnRefreshing(refreshControl)
            }
        } else {
            if fetchedItems.count == 0 {
                footerLoadingView.state = .loading
            }
        }
        let operationId = UUID().uuidString
        currentOperationId = operationId
        
        delegate.load(offset: nil, completion: { [weak self] (objects, error, newOffset) in
            guard let wSelf = self else {
                return
            }
            if wSelf.currentOperationId != operationId {
                return
            }
            wSelf.loading = false
            if let error = error as NSError? {
                if error.code != NSURLErrorCancelled {
                    wSelf.footerLoadingView.state = .failed
                    if refreshControl != nil {
                        wSelf.processPullToRefreshError(wSelf, error)
                    }
                    wSelf.delegate.reloadView(false)
                } else {
                    wSelf.footerLoadingView.state = .stop
                }
            } else {
                wSelf.offset = newOffset
                if wSelf.offset == nil {
                    wSelf.setFooterVisible(false, wSelf.footerLoadingView)
                }
                let oldObjects = wSelf.fetchedItems
                wSelf.fetchedItems = []
                wSelf.append(items: objects, animated: oldObjects.count > 0)
                wSelf.delegate.cachable()?.saveFirstPageInCache(objects: objects)
                wSelf.footerLoadingView.state = .stop
                if wSelf.offset != nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.loadModeIfNeeded()
                    }
                }
            }
            wSelf.endRefreshing()
        })
    }
    
    private func endRefreshing() {
        guard let refreshControl = refreshControl else {
            return
        }
        
        if scrollView.isDecelerating || scrollView.isDragging {
            shouldEndRefreshing = true
        } else if scrollView.window != nil && refreshControl.isRefreshing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                refreshControl.endRefreshing()
            })
        } else {
            refreshControl.endRefreshing()
        }
    }
    
    open func validateFetchedItems(_ closure: (AnyHashable)->(Bool)) {
        fetchedItems = fetchedItems.compactMap { closure($0) ? $0 : nil }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if delegate == nil {
            return
        }
        if keyPath == "contentOffset" {
            loadModeIfNeeded()
        }
    }
    
    private func loadModeIfNeeded() {
        if delegate.shouldLoadMore?() ?? true {
            
            if footerLoadingView.state == .failed && !isFooterVisible() {
                footerLoadingView.state = .stop
            }
            
            if footerLoadingView.state != .failed &&
                footerLoadingView.state != .loading &&
                !performedLoading &&
                !loading &&
                isFooterVisible() &&
                (refreshControl == nil || fetchedItems.count != 0) {
                
                loadMore()
            }
        }
    }
    
    private func isFooterVisible() -> Bool {
        scrollView.delegate?.scrollViewDidScroll?(scrollView)
        
        var frame = scrollView.convert(footerLoadingView.bounds, from: footerLoadingView)
        frame.origin.x -= footerLoadingInset.width
        frame.size.width += footerLoadingInset.width
        frame.origin.y -= footerLoadingInset.height
        frame.size.height += footerLoadingInset.height
        
        return footerLoadingView.isDescendant(of: scrollView) &&
            (scrollView.contentSize.height > scrollView.frame.size.height ||
            scrollView.contentSize.width > scrollView.frame.size.width ||
            scrollView.contentSize.height > 0) && scrollView.bounds.intersects(frame)
    }
    
    func endDecelerating() {
        performedLoading = false
        if shouldEndRefreshing && !scrollView.isDecelerating && !scrollView.isDragging {
            shouldEndRefreshing = false
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
        }
        if shouldBeginRefreshing {
            shouldBeginRefreshing = false
            refresh(with: refreshControl)
        }
    }
    
    deinit {
        scrollView.removeObserver(self, forKeyPath: "contentOffset")
    }
}

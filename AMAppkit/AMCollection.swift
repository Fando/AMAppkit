//
//  AMCollection.swift
//  AMAppkit
//
//  Created by Ilya Kuznetsov on 11/28/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation

@objc public protocol CollectionDelegate: UICollectionViewDelegate {
    
    @objc optional func shouldShowNoData(_ objects: [AnyHashable], collection: AMCollection) -> Bool
    
    @objc optional func viewSizeFor(view: UIView, defaultSize: CGSize, collection: AMCollection) -> CGSize
    
    //BOOL returns is we need to deselect cell
    @objc optional func action(object: Any, collection: AMCollection) -> AResult
    
    @objc optional func createCell(object: Any, collection: AMCollection) -> Any?
    
    @objc optional func cellSizeFor(object: Any, collection: AMCollection) -> CGSize
    
    @objc optional func move(object: Any) -> ((/*source*/IndexPath, /*proposed target*/ IndexPath)->())?
    @objc optional func proposeMoving(object: Any, toIndexPath: IndexPath) -> IndexPath
}

public struct CCell {
    public var cellType: UICollectionViewCell.Type
    public var cellFill: ((UICollectionViewCell)->())?
    
    public init<T: UICollectionViewCell>(_ type: T.Type, _ fill: ((T)->())?) {
        self.cellType = type
        if let fill = fill {
            self.cellFill = { (cell) in
                fill(cell as! T)
            }
        }
    }
}

open class AMCollection: StaticSetupObject {
    
    @objc public static var defaultDelegate: CollectionDelegate?
    
    @objc open var animationFix: Bool = false //fixes animation for insert/delete but duplicates reloading
    @objc open private(set) var objects: [AnyHashable] = []
    @objc open private(set) var collection: AMCollectionView!
    @objc open dynamic var layout: UICollectionViewFlowLayout? {
        get {
            return collection.collectionViewLayout as? UICollectionViewFlowLayout
        }
    }
    @objc private var deferredUpdate: Bool = false
    @objc open var visible: Bool = true { // defer reload when view is not visible
        didSet {
            if visible && (visible != oldValue) && deferredUpdate {
                set(objects: self.objects, animated: false)
            }
        }
    }
    
    //empty state
    @objc open var noObjectsViewType: AMNoObjectsView.Type! {
        didSet {
            self.noObjectsView = noObjectsViewType.loadFromNib()
        }
    }
    @objc open private(set) var noObjectsView: AMNoObjectsView!
    
    weak var delegate: CollectionDelegate?
   
    private var updatingDatasource: Bool = false
    private var lazyObjects: [Any]?
    
    open var setupViewContainer: ((AMContainerCell)->())?
    
    @objc public init(collection: AMCollectionView, delegate: CollectionDelegate) {
        super.init()
        self.collection = collection
        self.delegate = delegate
        setup()
    }
    
    @objc public init(view: UIView, delegate: CollectionDelegate) {
        super.init()
        self.createCollectionView()
        self.delegate = delegate
        
        collection.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: view.bounds.size.height)
        view.addSubview(collection)
        collection.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[collection]|", options: [], metrics: nil, views: ["collection":collection!]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[collection]|", options: [], metrics: nil, views: ["collection":collection!]))
        setup()
    }
    
    @objc public init(customAdd: (AMCollectionView)->(), delegate: CollectionDelegate) {
        super.init()
        createCollectionView()
        self.delegate = delegate
        customAdd(collection)
        setup()
    }
    
    @objc private func createCollectionView() {
        let layout = AMCollectionViewLeftAlignedLayout()
        layout.horizontalAlignment = .left
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collection = AMCollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        collection.backgroundColor = UIColor.clear
        collection.alwaysBounceVertical = true
    }
    
    func setup() {
        collection.delegate = self
        collection.dataSource = self
        collection.register(AMContainerCell.self, forCellWithReuseIdentifier: String(describing: AMContainerCell.self))
        noObjectsViewType = AMNoObjectsView.self
    }
    
    @objc open func set(objects: [Any], animated: Bool) {
        if updatingDatasource {
            lazyObjects = objects
        } else {
            updatingDatasource = true
            
            set(objects: objects, animated: animated, completion: { [weak self] in
                if let wSelf = self {
                    if let lazyObject = wSelf.lazyObjects {
                        wSelf.set(objects: lazyObject, animated: false, completion: nil)
                        wSelf.lazyObjects = nil
                    } else {
                        if wSelf.animationFix {
                            // fixes layout for further animation
                            DispatchQueue.main.async {
                                if !wSelf.updatingDatasource {
                                    UIView.performWithoutAnimation {
                                        if wSelf.delegate != nil {
                                            wSelf.collection.reloadSections(IndexSet(integer: 0))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                self?.updatingDatasource = false
            })
        }
    }
    
    private func set(objects: [Any], animated: Bool, completion: (()->())?) {
        let oldObjects = self.objects
        let resultObjects = objects.map { (object) -> AnyHashable in
            if let object = object as? NSObject {
                return object
            }
            return object as! AnyHashable
        }
        
        if !visible {
            self.objects = resultObjects
            deferredUpdate = true
            completion?()
            return
        }
        
        if delegate == nil {
            return
        }
            
        if !deferredUpdate {
            let toReload = collection.reload(animated: animated, oldData: oldObjects, data: resultObjects, completion: completion, updateObjects: {
                self.objects = resultObjects
            })
            collection.layoutIfNeeded()
            
            if let toReload = toReload, animated {
                toReload.forEach {
                    if let cell = collection.cellForItem(at: $0), cell as? AMContainerCell == nil {
                        let object = resultObjects[$0.item] as Any // swift bug workaround
                        
                        let createCell = self.delegate?.createCell?(object: object, collection: self) ??
                            type(of: self).defaultDelegate?.createCell?(object: object, collection: self)
                        (createCell as! CCell).cellFill?(cell)
                    }
                }
            }
        } else {
            self.objects = resultObjects
            collection.reloadData()
            deferredUpdate = false
            completion?()
        }
        
        if delegate?.shouldShowNoData?(resultObjects, collection: self) ??
            (type(of: self).defaultDelegate?.shouldShowNoData?(resultObjects, collection: self) ?? (objects.count == 0)) {
            noObjectsView.frame = CGRect(x: 0, y: 0, width: collection.frame.size.width, height: collection.frame.size.height)
            collection.addSubview(noObjectsView)
        } else {
            noObjectsView.removeFromSuperview()
        }
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        if !super.responds(to: aSelector) {
            return delegate != nil ? (delegate?.responds(to: aSelector) ?? false) : false
        }
        return true
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if !super.responds(to: aSelector) {
            return delegate
        }
        return self
    }
    
    deinit {
        collection.delegate = nil
        collection.dataSource = nil
    }
}

extension AMCollection: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return objects.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let object = objects[indexPath.item] as Any // swift bug workaround
        
        if let view = object as? UIView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: AMContainerCell.self), for: indexPath) as! AMContainerCell
            cell.attach(view: view)
            setupViewContainer?(cell)
            return cell
        } else {
            let createCell = (delegate?.createCell?(object: object, collection: self) ??
                type(of: self).defaultDelegate?.createCell?(object: object, collection: self)) as! CCell
            
            let cell = self.collection.createCell(for: createCell.cellType, at: indexPath)
            createCell.cellFill?(cell)
            
            return cell
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        let object = objects[indexPath.item] as Any
        return delegate?.move?(object: object) ?? type(of: self).defaultDelegate?.move?(object: object) != nil
    }
    
    public func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let object = objects[sourceIndexPath.item] as Any
        if let closure = delegate?.move?(object: object) ?? type(of: self).defaultDelegate?.move?(object: object) {
            closure(sourceIndexPath, destinationIndexPath)
            objects.remove(at: sourceIndexPath.item)
            objects.insert(object as! AnyHashable, at: destinationIndexPath.item)
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        let object = objects[originalIndexPath.item] as Any
        return delegate?.proposeMoving?(object: object, toIndexPath: proposedIndexPath) ?? type(of: self).defaultDelegate?.proposeMoving?(object: object, toIndexPath: proposedIndexPath) ?? proposedIndexPath
    }
}

extension AMCollection: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let object = objects[indexPath.item] as Any // swift bug workaround
        
        var result = delegate?.action?(object: object, collection: self)
        if result == nil || result! == .unsupported {
            result = type(of: self).defaultDelegate?.action?(object: object, collection: self)
        }
        if result == nil || result! == .select {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

extension AMCollection: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let object = objects[indexPath.item] as Any // swift bug workaround
        
        if let view = object as? UIView {
            
            if view.superview == nil { // perfrom initial trait collection set
                collectionView.addSubview(view)
                view.removeFromSuperview()
            }
            
            let insets = self.layout?.sectionInset
            let defaultWidth = collectionView.frame.size.width - (insets?.left ?? 0) - (insets?.right ?? 0)
            
            let targetView = view.superview ?? view
            
            var defaultSize = targetView.systemLayoutSizeFitting(CGSize(width: defaultWidth, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000), verticalFittingPriority: UILayoutPriority(rawValue: 1))
            defaultSize.width = defaultWidth
            
            var size = delegate?.viewSizeFor?(view: view, defaultSize: defaultSize, collection: self)
            if size == nil || size! == CGSize.zero {
                size = type(of: self).defaultDelegate?.viewSizeFor?(view: view, defaultSize: defaultSize, collection: self)
            }
            if let size = size {
                return CGSize(width: floor(size.width), height: ceil(size.height))
            }
            
            var frame = view.frame
            frame.size.width = defaultWidth
            view.frame = frame
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            return CGSize(width: floor(frame.size.width), height: ceil(view.systemLayoutSizeFitting(CGSize(width: defaultWidth, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000), verticalFittingPriority: UILayoutPriority(rawValue: 1)).height))
        } else {
            var size = delegate?.cellSizeFor?(object: object, collection: self)
            
            if size == nil || size! == CGSize.zero {
                size = type(of: self).defaultDelegate?.cellSizeFor?(object: object, collection: self)
            }
            return size!
        }
    }
}

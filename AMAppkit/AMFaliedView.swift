//
//  AMFaliedView.swift
//  AMAppkit
//
//  Created by Ilya Kuznetsov on 11/28/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation

@objcMembers
open class AMFailedView: UIView {
    
    @IBOutlet open var textLabel: UILabel!
    @IBOutlet open var retryButton: AMBorderedButton!
    
    private var retry: (()->())? {
        didSet {
            if retryButton != nil {
                retryButton.isHidden = retry == nil
            }
        }
    }
    
    open class func present(in view: UIView, text: String, retry: (()->())?) -> Self {
        let faliedView = self.loadFromNib()
        faliedView.frame = view.bounds
        faliedView.textLabel.text = text
        faliedView.retry = retry
        view.addSubview(faliedView)
        
        faliedView.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[failedView]|", options: [], metrics: nil, views: ["failedView":faliedView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[failedView]|", options: [], metrics: nil, views: ["failedView":faliedView]))
        faliedView.configure()
        
        return faliedView
    }
    
    open func configure() { }
    
    @IBAction private func retryAction(_ sender: UIButton) {
        retry?()
    }
}

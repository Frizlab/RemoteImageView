/*
Copyright 2021 François Lamboley

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation
import os.log
import UIKit



extension UIView {
	
	public convenience init(noAutoresizeWithFrame frame: CGRect, backgroundColor bgColor: UIColor? = nil) {
		self.init(frame: frame)
		translatesAutoresizingMaskIntoConstraints = false
		if let bgColor = bgColor {backgroundColor = bgColor}
	}
	
	/**
	 Add the given view to self’s subviews (at the end if `index` is `nil`) and make the added view fill `self` (`subview.frame = self.bounds`).
	 
	 If the added view uses autolayout (`translatesAutoresizingMaskIntoConstraints` is `false`), we add constraints so the subview always has its parent’s size.
	 If not, we simply set the added view’s frame to self’s bounds. */
	public func addFullSizedSubview(_ addedView: UIView, at index: Int? = nil) {
		if let index = index {insertSubview(addedView, at: index)}
		else                 {addSubview(addedView)}
		
		if !addedView.translatesAutoresizingMaskIntoConstraints {
			NSLayoutConstraint.activate(
				NSLayoutConstraint.constraints(withVisualFormat: "H:|[V]|", options: [], metrics: nil, views: ["V": addedView]) +
				NSLayoutConstraint.constraints(withVisualFormat: "V:|[V]|", options: [], metrics: nil, views: ["V": addedView])
			)
		} else {
			addedView.frame = bounds
			if !translatesAutoresizingMaskIntoConstraints {
				Logger.utils.info("Got a view which translates autoresizing mask into constraints to fill a \(Self.self), which does not.")
			}
		}
	}
	
}

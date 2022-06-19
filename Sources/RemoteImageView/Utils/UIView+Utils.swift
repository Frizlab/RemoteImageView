/*
Copyright 2021-2022 François Lamboley

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
	
	convenience init(noAutoresizeWithFrame frame: CGRect, backgroundColor bgColor: UIColor? = nil) {
		self.init(frame: frame)
		translatesAutoresizingMaskIntoConstraints = false
		if let bgColor = bgColor {backgroundColor = bgColor}
	}
	
	/**
	 Add the given view to self’s subviews (at the end if `index` is `nil`) and make the added view fill `self` (`subview.frame = self.bounds`).
	 
	 If the added view uses autolayout (`translatesAutoresizingMaskIntoConstraints` is `false`), we add constraints so the subview always has its parent’s size.
	 If not, we simply set the added view’s frame to self’s bounds. */
	func addFullSizedSubview(_ addedView: UIView, topSpace: CGFloat? = 0, leadingSpace: CGFloat? = 0, bottomSpace: CGFloat? = 0, trailingSpace: CGFloat? = 0, at index: Int? = nil) {
		if let index = index {insertSubview(addedView, at: index)}
		else                 {addSubview(addedView)}
		
		let tVFL = (     topSpace == nil ? "" : "(T)-")
		let lVFL = ( leadingSpace == nil ? "" : "(L)-")
		let bVFL = (  bottomSpace == nil ? "" : "-(B)")
		let rVFL = (trailingSpace == nil ? "" : "-(R)")
		if !addedView.translatesAutoresizingMaskIntoConstraints {
			NSLayoutConstraint.activate(
				NSLayoutConstraint.constraints(withVisualFormat: "H:|-\(lVFL)[V]\(rVFL)-|", options: [], metrics: ["L": leadingSpace as Any, "R": trailingSpace as Any], views: ["V": addedView]) +
				NSLayoutConstraint.constraints(withVisualFormat: "V:|-\(tVFL)[V]\(bVFL)-|", options: [], metrics: ["T":     topSpace as Any, "B":   bottomSpace as Any], views: ["V": addedView])
			)
		} else {
			let      topSpace =      topSpace ?? 0
			let  leadingSpace =  leadingSpace ?? 0
			let   bottomSpace =   bottomSpace ?? 0
			let trailingSpace = trailingSpace ?? 0
			let isLTR = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .leftToRight
			addedView.frame = CGRect(
				x: (isLTR ? leadingSpace : trailingSpace),
				y: topSpace,
				width: bounds.width - leadingSpace - trailingSpace,
				height: bounds.height - topSpace - bottomSpace
			)
			if !translatesAutoresizingMaskIntoConstraints {
				Logger.utils.info("Got a view which translates autoresizing mask into constraints to fill a \(Self.self), which does not.")
			}
		}
	}
	
}

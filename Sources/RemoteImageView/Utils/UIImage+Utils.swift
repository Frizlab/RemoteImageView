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

import os.log
import UIKit



extension UIImage {
	
	/**
	 Resize the given image.
	 
	 Resize the given image to the new given size (in points) with the given content mode.
	 The resulting image will have the same scale factor as the original image.
	 
	 - Important: We emulate the content mode; we do not use UIKit to draw the image using it.
	 Some content modes are not supported (or do not make sense for a static image render). We will crash for those.
	 Some content modes might have different results than UIKit renders, though tried our best to match UIKit. */
	func resized(to originalNewSize: CGSize, contentMode: UIView.ContentMode, insets: UIEdgeInsets = .zero, backgroundColor: UIColor? = nil) -> UIImage {
		/* Inspired by https://nshipster.com/image-resizing/. */
		let newSize = CGSize(
			width:  originalNewSize.width  - insets.left - insets.right,
			height: originalNewSize.height - insets.top  - insets.bottom
		)
		
		let rect: CGRect
		switch contentMode {
			case .scaleToFill:
				rect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: newSize)
				
			case .scaleAspectFit: fallthrough
			case .scaleAspectFill:
				let ratioSource =    size.width /    size.height
				let ratioDest   = newSize.width / newSize.height
				
				let destDrawingSize: CGSize
				let unmodifiedWidth = (
					contentMode == .scaleAspectFit  && ratioDest <= ratioSource ||
					contentMode == .scaleAspectFill && ratioDest >  ratioSource
				)
				if unmodifiedWidth {destDrawingSize = CGSize(width: newSize.width, height: newSize.width / ratioSource)}
				else               {destDrawingSize = CGSize(width: newSize.height * ratioSource, height: newSize.height)}
				rect = CGRect(
					origin: CGPoint(
						x: (newSize.width  - destDrawingSize.width )/2 + insets.left,
						y: (newSize.height - destDrawingSize.height)/2 + insets.top
					),
					size: destDrawingSize
				)
				
			case .center:      rect = CGRect(origin: CGPoint(x: (originalNewSize.width - size.width + insets.left - insets.right)/2, y: (originalNewSize.height - size.height + insets.top - insets.bottom)/2), size: size)
			case .top:         rect = CGRect(origin: CGPoint(x: (originalNewSize.width - size.width + insets.left - insets.right)/2, y: insets.top),                                                            size: size)
			case .bottom:      rect = CGRect(origin: CGPoint(x: (originalNewSize.width - size.width + insets.left - insets.right)/2, y: (originalNewSize.height - size.height - insets.bottom)),                size: size)
			case .left:        rect = CGRect(origin: CGPoint(x: insets.left,                                                         y: (originalNewSize.height - size.height + insets.top - insets.bottom)/2), size: size)
			case .right:       rect = CGRect(origin: CGPoint(x: (originalNewSize.width - size.width - insets.right),                 y: (originalNewSize.height - size.height + insets.top - insets.bottom)/2), size: size)
			case .topLeft:     rect = CGRect(origin: CGPoint(x: insets.left,                                                         y: insets.top),                                                            size: size)
			case .topRight:    rect = CGRect(origin: CGPoint(x: (originalNewSize.width - size.width - insets.right),                 y: insets.top),                                                            size: size)
			case .bottomLeft:  rect = CGRect(origin: CGPoint(x: insets.left,                                                         y: (originalNewSize.height - size.height - insets.bottom)),                size: size)
			case .bottomRight: rect = CGRect(origin: CGPoint(x: (originalNewSize.width - size.width - insets.right),                 y: (originalNewSize.height - size.height - insets.bottom)),                size: size)
				
			case .redraw:
				fatalError("The “redraw” content mode does not make sense for a resize operation.")
				
			@unknown default:
				Logger.utils.warning("Unknown content mode \(String(describing: contentMode)); using scaleToFill.")
				rect = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: newSize)
		}
		
		let renderer = UIGraphicsImageRenderer(size: originalNewSize, format: {
			let format = UIGraphicsImageRendererFormat.default()
			format.scale = scale
			return format
		}())
		return renderer.image{ context in
			if let backgroundColor {
				backgroundColor.setFill()
				context.fill(CGRect(origin: .zero, size: originalNewSize))
			}
			draw(in: rect)
		}
	}
	
	/** _Synchronously_ compute a darkened and blurred version of the given image using CoreImage. */
	func darkenedAndBlurred(darkenAmount: CGFloat, blurRadius: CGFloat, cutBlurredBorders: Bool = true) -> UIImage? {
		/* Highly inspired by https://stackoverflow.com/a/17041983 and https://stackoverflow.com/a/55581057.
		 * From https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_performance/ci_performance.html#//apple_ref/doc/uid/TP30001185-CH10-SW1
		 *  we learn we might want to disable color management for performance as we don’t really care about color accuracy.
		 * How we should do that is another question (that I’m not the only one to ask: https://stackoverflow.com/q/46998872). */
		guard let darkenFilter = CIFilter(name: "CIColorPolynomial"),
				let blurFilter = CIFilter(name: "CIGaussianBlur"),
				let ciImage = (ciImage ?? cgImage.flatMap{ CIImage(cgImage: $0) })
		else {
			return nil
		}
		
		darkenFilter.setValue(ciImage, forKey: kCIInputImageKey)
		darkenFilter.setValue(CIVector(x: 0, y: (1 - darkenAmount), z: 0, w: 0), forKey: "inputRedCoefficients")
		darkenFilter.setValue(CIVector(x: 0, y: (1 - darkenAmount), z: 0, w: 0), forKey: "inputGreenCoefficients")
		darkenFilter.setValue(CIVector(x: 0, y: (1 - darkenAmount), z: 0, w: 0), forKey: "inputBlueCoefficients")
		
		blurFilter.setValue(darkenFilter.outputImage, forKey: kCIInputImageKey)
		blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
		
		let inset = cutBlurredBorders ? blurRadius : 0
		guard let blurredCIImage = blurFilter.outputImage,
				let blurredCGImage = Self.ciContext.createCGImage(blurredCIImage, from: ciImage.extent.inset(by: .init(top: inset, left: inset, bottom: inset, right: inset)))
		else {
			return nil
		}
		
		return UIImage(cgImage: blurredCGImage, scale: scale, orientation: imageOrientation)
	}
	
	private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
	
}

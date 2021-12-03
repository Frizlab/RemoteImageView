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

import Combine
import Foundation
import os.log
import UIKit



@MainActor
@IBDesignable
public final class RemoteImageView : UIView {
	
	public enum UIState {
		
		case showingImage
		case showingNil
		case showingLoading
		case showingError
		
		/** Special case where view should be showing nil or error or loading, but none of these views are defined. */
		case showingNothing
		
		case unclean
		case invalid
		
	}
	
	public var uiState: UIState {
		let imageDelta   =  viewImage.alpha          - 0.5
		let nilDelta     = (viewNil?.alpha     ?? 0) - 0.5
		let loadingDelta = (viewLoading?.alpha ?? 0) - 0.5
		let errorDelta   = (viewError?.alpha   ?? 0) - 0.5
		
		var isClean = true
		if abs(abs(imageDelta)   - 0.5) > 0.05 {isClean = false; Logger.view.warning("Got invalid imageView alpha \(   self.viewImage.alpha        ) in a RemoteImageView")}
		if abs(abs(nilDelta)     - 0.5) > 0.05 {isClean = false; Logger.view.warning("Got invalid viewNil alpha \(     self.viewNil?.alpha     ?? 0) in a RemoteImageView")}
		if abs(abs(loadingDelta) - 0.5) > 0.05 {isClean = false; Logger.view.warning("Got invalid loadingDelta alpha \(self.viewLoading?.alpha ?? 0) in a RemoteImageView")}
		if abs(abs(errorDelta)   - 0.5) > 0.05 {isClean = false; Logger.view.warning("Got invalid viewError alpha \(   self.viewError?.alpha   ?? 0) in a RemoteImageView")}
		guard isClean else {
			return .unclean
		}
		
		switch (imageDelta > 0, nilDelta > 0, loadingDelta > 0, errorDelta > 0) {
			case (true, false, false, false): return .showingImage
			case (false, true, false, false): return .showingNil
			case (false, false, true, false): return .showingLoading
			case (false, false, false, true): return .showingError
			default: return abs(viewImage.alpha) < 0.05 && viewNil == nil && viewLoading == nil && viewError == nil ? .showingNothing : .invalid
		}
	}
	
	/**
	 The image view is accessible publicly so that presentation options can be changed easily (e.g. stretch mode).
	 You should not change the image displayed, the alpha, etc.
	 These will be changed by the view-model.
	 
	 _Dev note_: We’re using a lazy var to avoid initing the property in the init (there are two init methods).
	 This property is thus technically a `var` and can be modified, but in spririt it is a `let`. */
	public private(set) lazy var viewImage: UIImageView = {
		let imageView = UIImageView(frame: bounds)
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.contentMode = .scaleAspectFill
		addFullSizedSubview(imageView)
		return imageView
	}()
	
	/** If `nil`, the view will be empty when the view-model state is `noImage`, or when the view-model itself is `nil`. */
	public var viewNil: UIView? {
		didSet {
			oldValue?.removeFromSuperview()
			
			guard let viewNil = viewNil else {return}
			addFullSizedSubview(viewNil, at: 0)
		}
	}
	
	/** If `nil`, the ``viewNil`` will be used when the view-model state is `loading`. */
	public var viewLoading: UIView? {
		didSet {
			oldValue?.removeFromSuperview()
			
			guard let viewLoading = viewLoading else {return}
			addFullSizedSubview(viewLoading, at: 0)
		}
	}
	
	/** If `nil`, the ``viewNil`` will be used when the view-model state is `loadingError`. */
	public var viewError: UIView? {
		didSet {
			oldValue?.removeFromSuperview()
			
			guard let viewError = viewError else {return}
			addFullSizedSubview(viewError, at: 0)
		}
	}
	
	public var viewModel: RemoteImageViewModel = DefaultRemoteImageViewModel() {
		willSet {
			remoteImageStateObserver = nil
		}
		didSet {
			updateViewModelBindings()
		}
	}
	
	public override init(frame: CGRect) {
		super.init(frame: frame)
		
		clipsToBounds = true
		updateViewModelBindings()
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		
		clipsToBounds = true
		updateViewModelBindings()
	}
	
	public func setImage(_ image: UIImage?, animated: Bool = false) {
		viewModel.setImage(image, animated: animated)
	}
	
	public func setImageFromURL(_ url: URL, animateInitialChange: Bool = false, animateDidLoadChange: Bool = true) {
		setImageFromURLRequest(URLRequest(url: url), animateInitialChange: animateInitialChange, animateDidLoadChange: animateDidLoadChange)
	}
	
	public func setImageFromURLRequest(_ urlRequest: URLRequest, animateInitialChange: Bool = false, animateDidLoadChange: Bool = true) {
		viewModel.setImageFromURLRequest(urlRequest, animateInitialChange: animateInitialChange, animateDidLoadChange: animateDidLoadChange)
	}
		
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var remoteImageStateObserver: AnyCancellable?
	
	private func updateViewModelBindings() {
		assert(Thread.isMainThread)
		
		updateSubviews()
		remoteImageStateObserver = viewModel.imageState
			.receive(on: DispatchQueue.main)
			.sink{ [weak self] _ in self?.updateSubviews() }
	}
	
	private func updateSubviews() {
		assert(Thread.isMainThread)
		switch viewModel.imageState.value {
			case let (.noImage, animated):
				showNilSubview(animated: animated)
				
			case let (.loadedImage(image), animated):
				viewImage.image = image /* Note: We do _not_ animate image change (yet?) */
				showImageSubview(animated: animated)
				
			case let (.loading, animated):
				showLoadingSubview(animated: animated)
				
			case let (.loadingError, animated):
				showErrorSubview(animated: animated)
		}
	}
	
	private func showImageSubview(animated: Bool) {
		assert(Thread.isMainThread)
		let setAlphas = {
			self.viewImage.alpha    = 1
			self.viewNil?.alpha     = 0
			self.viewLoading?.alpha = 0
			self.viewError?.alpha   = 0
		}
		if animated {
			viewModel.applyUIChanges(animatable: setAlphas, cleanup: imageViewCleanup)
		} else {
			setAlphas()
			imageViewCleanup()
		}
	}
	
	private func showNilSubview(animated: Bool) {
		assert(Thread.isMainThread)
		let setAlphas = {
			self.viewImage.alpha    = 0
			self.viewNil?.alpha     = 1
			self.viewLoading?.alpha = 0
			self.viewError?.alpha   = 0
		}
		if animated {
			viewModel.applyUIChanges(animatable: setAlphas, cleanup: imageViewCleanup)
		} else {
			setAlphas()
			imageViewCleanup()
		}
	}
	
	private func showLoadingSubview(animated: Bool) {
		assert(Thread.isMainThread)
		guard viewLoading != nil else {
			return showNilSubview(animated: animated)
		}
		
		let setAlphas = {
			self.viewImage.alpha    = 0
			self.viewNil?.alpha     = 0
			self.viewLoading?.alpha = 1
			self.viewError?.alpha   = 0
		}
		if animated {
			viewModel.applyUIChanges(animatable: setAlphas, cleanup: imageViewCleanup)
		} else {
			setAlphas()
			imageViewCleanup()
		}
	}
	
	private func showErrorSubview(animated: Bool) {
		assert(Thread.isMainThread)
		guard viewError != nil else {
			return showNilSubview(animated: animated)
		}
		
		let setAlphas = {
			self.viewImage.alpha    = 0
			self.viewNil?.alpha     = 0
			self.viewLoading?.alpha = 0
			self.viewError?.alpha   = 1
		}
		if animated {
			viewModel.applyUIChanges(animatable: setAlphas, cleanup: imageViewCleanup)
		} else {
			setAlphas()
			imageViewCleanup()
		}
	}
	
	private func imageViewCleanup() {
		assert(Thread.isMainThread)
		switch uiState {
			case .showingImage: (/*nop*/)
				
			case .showingNil, .showingLoading, .showingError, .showingNothing:
				viewImage.image = nil
				
			case .unclean, .invalid:
				/* We don’t really know, let’s do nothing. */
				Logger.view.notice("Unclean or invalid UI state in image view cleanup.")
		}
	}
	
}

/*
 * RemoteImageView.swift
 * CommonViews
 *
 * Created by François Lamboley on 2021/11/21.
 * Copyright © 2021 Togever. All rights reserved.
 */

import Combine
import Foundation
import os.log
import UIKit



/* Note about this https://developer.apple.com/documentation/uikit/uiview/1622574-transition for animated states changes:
 *  I tried, but because we cross-dissolve w/o a bg, we get a flash of whatever is behind, and it’s ugly. */

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
	
	public var animationsDuration = RemoteImageViewConfig.defaultAnimationDuration
	
	/**
	 The image view is accessible publicly so that presentation options can be changed easily (e.g. content mode).
	 You should not change the image displayed, the alpha, etc.
	 These will be changed by the view-model.
	 
	 _Dev note_: We’re using a lazy var to avoid initing the property in the init (there are two init methods).
	 This property is thus technically a `var` and can be modified, but in spirit it is a `let`. */
	public private(set) lazy var viewImage: UIImageView = {
		let imageView = UIImageView(noAutoresizeWithFrame: bounds)
		imageView.contentMode = .scaleAspectFill
		addFullSizedSubview(imageView)
		return imageView
	}()
	
	/** If `nil`, the view will be empty when the view-model state is `noImage`, or when the view-model itself is `nil`. */
	public var viewNil: UIView? {
		didSet {
			oldValue?.removeFromSuperview()
			guard let viewNil = viewNil else {return}
			
			if !viewNil.isOpaque && viewNil.backgroundColor == nil {
				viewNil.backgroundColor = backgroundColor
			}
			
			viewNil.alpha = 0
			addFullSizedSubview(viewNil, at: 0)
			updateSubviews(state: (viewModel.imageState.value.state, false))
		}
	}
	
	/** If `nil`, the ``viewNil`` will be used when the view-model state is `loading`. */
	public var viewLoading: UIView? {
		didSet {
			oldValue?.removeFromSuperview()
			guard let viewLoading = viewLoading else {return}
			
			if !viewLoading.isOpaque && viewLoading.backgroundColor == nil {
				viewLoading.backgroundColor = backgroundColor
			}
			
			viewLoading.alpha = 0
			addFullSizedSubview(viewLoading, at: 0)
			updateSubviews(state: (viewModel.imageState.value.state, false))
		}
	}
	
	/** If `nil`, the ``viewNil`` will be used when the view-model state is `loadingError`. */
	public var viewError: UIView? {
		didSet {
			oldValue?.removeFromSuperview()
			guard let viewError = viewError else {return}
			
			if !viewError.isOpaque && viewError.backgroundColor == nil {
				viewError.backgroundColor = backgroundColor
			}
			
			viewError.alpha = 0
			addFullSizedSubview(viewError, at: 0)
			updateSubviews(state: (viewModel.imageState.value.state, false))
		}
	}
	
	public var viewModel: any RemoteImageViewModel = DefaultRemoteImageViewModel() {
		willSet {
			remoteImageStateObserver = nil
		}
		didSet {
			updateViewModelBindings()
		}
	}
	
	public override var backgroundColor: UIColor? {
		didSet {
			viewImage.backgroundColor = backgroundColor
			if let viewNil, !viewNil.isOpaque && viewNil.backgroundColor == nil {
				viewNil.backgroundColor = backgroundColor
			}
			if let viewLoading, !viewLoading.isOpaque && viewLoading.backgroundColor == nil {
				viewLoading.backgroundColor = backgroundColor
			}
			if let viewError, !viewError.isOpaque && viewError.backgroundColor == nil {
				viewError.backgroundColor = backgroundColor
			}
		}
	}
	
	public var uiState: UIState {
		let imageDelta   =  viewImage.alpha          - 0.5
		let nilDelta     = (viewNil?.alpha     ?? 0) - 0.5
		let loadingDelta = (viewLoading?.alpha ?? 0) - 0.5
		let errorDelta   = (viewError?.alpha   ?? 0) - 0.5
		
		var isClean = true
		if abs(abs(imageDelta)   - 0.5) > 0.5 {isClean = false; Logger.view.warning("Got invalid imageView alpha \(   self.viewImage.alpha        ) in a RemoteImageView")}
		if abs(abs(nilDelta)     - 0.5) > 0.5 {isClean = false; Logger.view.warning("Got invalid viewNil alpha \(     self.viewNil?.alpha     ?? 0) in a RemoteImageView")}
		if abs(abs(loadingDelta) - 0.5) > 0.5 {isClean = false; Logger.view.warning("Got invalid loadingDelta alpha \(self.viewLoading?.alpha ?? 0) in a RemoteImageView")}
		if abs(abs(errorDelta)   - 0.5) > 0.5 {isClean = false; Logger.view.warning("Got invalid viewError alpha \(   self.viewError?.alpha   ?? 0) in a RemoteImageView")}
		guard isClean else {
			return .unclean
		}
		
		switch (imageDelta > 0, nilDelta > 0, loadingDelta > 0, errorDelta > 0) {
			case (false, false, false, false): return .showingNothing
			case (true,  false, false, false): return .showingImage
			case (false,  true, false, false): return .showingNil
			case (false, false,  true, false): return .showingLoading
			case (false, false, false,  true): return .showingError
			default: return abs(viewImage.alpha) < 0.05 && viewNil == nil && viewLoading == nil && viewError == nil ? .showingNothing : .invalid
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
	
	public func setFakeLoading(animated: Bool = false) {
		viewModel.setFakeLoading(animated: animated)
	}
	
	public func setImage(_ image: UIImage?, animated: Bool = false) {
		viewModel.setImage(image, animated: animated)
	}
	
	public func setImageFromURL(_ url: URL?, nilIsLoading: Bool = false, useMemoryCache: Bool? = nil, animateInitialChange: Bool = false, animateDidLoadChange: Bool = true) {
		setImageFromRequest(url.flatMap{ RemoteImageURLRequest(url: $0) }, nilIsLoading: nilIsLoading, useMemoryCache: useMemoryCache, animateInitialChange: animateInitialChange, animateDidLoadChange: animateDidLoadChange)
	}
	
	public func setImageFromURLRequest(_ urlRequest: URLRequest?, nilIsLoading: Bool = false, useMemoryCache: Bool? = nil, animateInitialChange: Bool = false, animateDidLoadChange: Bool = true) {
		setImageFromRequest(urlRequest.flatMap{ RemoteImageURLRequest(urlRequest: $0) }, nilIsLoading: nilIsLoading, useMemoryCache: useMemoryCache, animateInitialChange: animateInitialChange, animateDidLoadChange: animateDidLoadChange)
	}
	
	public func setImageFromRequest(_ request: RemoteImageViewRequest?, nilIsLoading: Bool = false, useMemoryCache: Bool? = nil, animateInitialChange: Bool = false, animateDidLoadChange: Bool = true) {
		if nilIsLoading && request == nil {
			setFakeLoading(animated: animateInitialChange)
		} else {
			viewModel.setImageFromRequest(request, useMemoryCache: useMemoryCache, animateInitialChange: animateInitialChange, animateDidLoadChange: animateDidLoadChange)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var remoteImageStateObserver: AnyCancellable?
	
	private var snapView: UIView?
	private var animating = false
	private var nextState: (state: RemoteImageState, shouldAnimateChange: Bool)?
	
	private func updateViewModelBindings() {
		assert(Thread.isMainThread)
		
		remoteImageStateObserver = viewModel.imageState
			.receive(on: DispatchQueue.main)
			.sink{ [weak self] in self?.updateSubviews(state: $0) }
	}
	
	private func updateSubviews(state: (state: RemoteImageState, shouldAnimateChange: Bool)) {
		assert(Thread.isMainThread)
		
		guard !animating else {
			nextState = state
			if !state.shouldAnimateChange {
				CALayer.removeAllAnimationRecursively(layer)
			}
			return
		}
		
		switch state {
			case let (.noImage(fakeLoading), animated) where !fakeLoading:
				showNilSubview(animated: animated)
				
			case let (.loadedImage(image), animated):
				showImageSubview(image, animated: animated)
				
			case let (.loading, animated), let (.noImage, animated):
				showLoadingSubview(animated: animated)
				
			case let (.loadingError, animated):
				showErrorSubview(animated: animated)
		}
	}
	
	private func showImageSubview(_ image: UIImage, animated: Bool) {
		assert(!animating)
		assert(Thread.isMainThread)
		
		let animation = {
			self.viewImage.alpha = 1
		}
		let cleanup = {
			self.viewNil?.alpha     = 0
			self.viewLoading?.alpha = 0
			self.viewError?.alpha   = 0
			
			self.animating = false
			self.imageViewCleanupAndNextStateCall()
		}
		if animated {
			assert(snapView == nil)
			snapView = viewImage.snapshotView(afterScreenUpdates: false)
			if let snapView = snapView {
				snapView.alpha = viewImage.alpha
				addSubview(snapView)
			}
			
			viewImage.alpha = 0
			viewImage.image = image
			
			animating = true
			bringSubviewToFront(viewImage)
			applyUIChanges(animatable: animation, cleanup: cleanup)
		} else {
			viewImage.image = image
			animation()
			cleanup()
		}
	}
	
	private func showNilSubview(animated: Bool) {
		assert(!animating)
		assert(Thread.isMainThread)
		
		let animation = {
			_ = self.viewNil?.alpha = 1
		}
		let hide = {
			self.viewImage.alpha    = 0
			self.viewLoading?.alpha = 0
			self.viewError?.alpha   = 0
		}
		let cleanup = {
			self.animating = false
			self.imageViewCleanupAndNextStateCall()
		}
		if animated {
			animating = true
			if let viewNil = viewNil {
				bringSubviewToFront(viewNil)
				applyUIChanges(animatable: animation, cleanup: { hide(); cleanup(); })
			} else {
				applyUIChanges(animatable: hide, cleanup: cleanup)
			}
		} else {
			animation()
			hide()
			cleanup()
		}
	}
	
	private func showLoadingSubview(animated: Bool) {
		assert(!animating)
		assert(Thread.isMainThread)
		guard let viewLoading = viewLoading else {
			return showNilSubview(animated: animated)
		}
		
		let animation = {
			_ = self.viewLoading?.alpha = 1
		}
		let cleanup = {
			self.viewImage.alpha  = 0
			self.viewNil?.alpha   = 0
			self.viewError?.alpha = 0
			
			self.animating = false
			self.imageViewCleanupAndNextStateCall()
		}
		if animated {
			animating = true
			bringSubviewToFront(viewLoading)
			applyUIChanges(animatable: animation, cleanup: cleanup)
		} else {
			animation()
			cleanup()
		}
	}
	
	private func showErrorSubview(animated: Bool) {
		assert(!animating)
		assert(Thread.isMainThread)
		guard let viewError = viewError else {
			return showNilSubview(animated: animated)
		}
		
		let animation = {
			_ = self.viewError?.alpha = 1
		}
		let cleanup = {
			self.viewImage.alpha    = 0
			self.viewNil?.alpha     = 0
			self.viewLoading?.alpha = 0
			
			self.animating = false
			self.imageViewCleanupAndNextStateCall()
		}
		if animated {
			animating = true
			bringSubviewToFront(viewError)
			applyUIChanges(animatable: animation, cleanup: cleanup)
		} else {
			animation()
			cleanup()
		}
	}
	
	private func imageViewCleanupAndNextStateCall() {
		assert(Thread.isMainThread)
		switch uiState {
			case .showingImage: (/*nop*/)
				
			case .showingNil, .showingLoading, .showingError, .showingNothing:
				viewImage.image = nil
				
			case .unclean, .invalid:
				/* We don’t really know, let’s do nothing. */
				Logger.view.notice("Unclean or invalid UI state in image view cleanup.")
		}
		
		snapView?.removeFromSuperview()
		snapView = nil
		
		if let nextState = self.nextState {
			self.nextState = nil
			self.updateSubviews(state: nextState)
		}
	}
	
	public func applyUIChanges(animatable: @MainActor @escaping () -> Void, cleanup: @MainActor @escaping () -> Void) {
		assert(Thread.isMainThread)
		UIView.animate(withDuration: animationsDuration, animations: { animatable() }, completion: { _ in cleanup() })
	}
	
}

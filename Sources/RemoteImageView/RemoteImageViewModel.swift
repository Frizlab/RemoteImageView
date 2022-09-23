/*
 * RemoteImageViewModel.swift
 * CommonViews
 *
 * Created by François Lamboley on 2021/11/25.
 * Copyright © 2021 Togever. All rights reserved.
 */

import Combine
import Foundation
import UIKit



public protocol RemoteImageViewRequest {
	
	/** If `nil`, no caching will be used. */
	var rlCacheKey: AnyHashable? {get}
	@Sendable func load() async throws -> UIImage
	
}


@MainActor
public protocol RemoteImageViewModel {
	
	/**
	 The state of the image (loading, loaded, error, etc.). */
	var imageState: CurrentValueSubject<(state: RemoteImageState, shouldAnimateChange: Bool), Never> {get}
	
	func setFakeLoading(animated: Bool)
	func setError(_ error: Error, animated: Bool)
	func setImage(_ image: UIImage?, animated: Bool)
	func setImageFromRequest(_ request: RemoteImageViewRequest?, useMemoryCache: Bool?, animateInitialChange: Bool, animateDidLoadChange: Bool)
	
}


public enum RemoteImageState {
	
	/**
	 No image set in the remote image view, with a parameter to specify the remote image view should show the loading view instead of the nil one.
	 
	 When loading a view, you might be waiting for some data from a back-end to know the URL to display in your remote image view.
	 The image view should usually show the loading view instead of the nil one while the URL is unknown.
	 This is an example of when to set `fakeLoading` to true. */
	case noImage(fakeLoading: Bool)
	
	case loading(RemoteImageViewRequest)
	case loadedImage(UIImage)
	case loadingError(Error)
	
}

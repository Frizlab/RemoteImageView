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



public protocol Request {
	
	/** If `nil`, no caching will be used. */
	var rlCacheKey: AnyHashable? {get}
	@Sendable func load() async throws -> UIImage
	
}


public protocol ImageLoader {
	
	/**
	 Load the given image and return a publisher giving the loading state. */
	func loadImage(from request: any Request, useMemoryCache: Bool?) -> any Publisher<UIImage, Error>
	
}


@MainActor
public struct ViewModel {
	
	public enum ShownView {
		
		case noImage
		case loading
		case image(UIImage)
		case error
		
	}
	
	public typealias State = (shownView: ShownView, shouldAnimateChange: Bool)
	public var statePublisher: any Publisher<State, Never> {statePublisherPublisher.switchToLatest()}
	
	public let imageLoader: any ImageLoader
	
	public init(shownView: ShownView, imageLoader: any ImageLoader = DefaultImageLoader()) {
		self.statePublisherPublisher = .init(Just((shownView, false)).eraseToAnyPublisher())
		self.imageLoader = imageLoader
	}
	
	func setLoading(animated: Bool) {
		statePublisherPublisher.send(Just((.loading, animated)).eraseToAnyPublisher())
	}
	
	func setError(_ error: Error, animated: Bool) {
		statePublisherPublisher.send(Just((.error, animated)).eraseToAnyPublisher())
	}
	
	func setImage(_ image: UIImage?, animated: Bool) {
		let shownView: ShownView
		if let image {shownView = .image(image)}
		else         {shownView = .noImage}
		statePublisherPublisher.send(Just((shownView, animated)).eraseToAnyPublisher())
	}
	
	func setImageFromRequest(_ request: any Request, useMemoryCache: Bool?, animateInitialChange: Bool, animateDidLoadChange: Bool) {
		statePublisherPublisher.value = Just((.loading, animateInitialChange)).eraseToAnyPublisher()
		statePublisherPublisher.value = imageLoader.loadImage(from: request, useMemoryCache: useMemoryCache).eraseToAnyPublisher()
			.map{ Result<UIImage, Error>.success($0) }
			.catch{ Just(.failure($0)) }
			.map{ imageResult in
				switch imageResult {
					case .failure:            return (ShownView.error,        animateDidLoadChange)
					case .success(let image): return (ShownView.image(image), animateDidLoadChange)
				}
			}
			.merge(with: Empty<State, Never>())
			.share()
			.eraseToAnyPublisher()
	}
	
	/* For iOS 16. */
//	private let statePublisherPublisher: CurrentValueSubject<any Publisher<State, Never>, Never>
	private let statePublisherPublisher: CurrentValueSubject<AnyPublisher<State, Never>, Never>
	
}

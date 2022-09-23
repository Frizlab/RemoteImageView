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

import Combine
import Foundation
import os.log
import UIKit

import HasResult
import OperationAwaiting
import URLRequestOperation



@MainActor
public final class DefaultRemoteImageViewModel : RemoteImageViewModel {
	
	public let useMemoryCache: Bool
	
	public let animationDuration: TimeInterval
	
	public let imageState: CurrentValueSubject<(state: RemoteImageState, shouldAnimateChange: Bool), Never>
	
	public nonisolated init(
		fakeLoading: Bool = false,
		useMemoryCache: Bool = RemoteImageViewConfig.defaultRemoteImageViewModelUsesMemoryCacheByDefault,
		animationDuration: TimeInterval = RemoteImageViewConfig.defaultAnimationDuration)
	{
		self.useMemoryCache = useMemoryCache
		self.animationDuration = animationDuration
		
		self.imageState = .init((.noImage(fakeLoading: fakeLoading), false))
	}
	
	deinit {
		currentSetImageTask?.task.cancel()
		currentSetImageTask = nil
	}
	
	public func setFakeLoading(animated: Bool) {
		currentSetImageTask?.task.cancel()
		currentSetImageTask = nil
		
		imageState.value = (.noImage(fakeLoading: true), animated)
	}
	
	public func setError(_ error: Error, animated: Bool) {
		currentSetImageTask?.task.cancel()
		currentSetImageTask = nil
		
		imageState.value = (.loadingError(error), animated)
	}
	
	public func setImage(_ image: UIImage?, animated: Bool) {
		currentSetImageTask?.task.cancel()
		currentSetImageTask = nil
		
		imageState.value = (image.flatMap{ .loadedImage($0) } ?? .noImage(fakeLoading: false), animated)
	}
	
	public func setImageFromRequest(_ request: RemoteImageViewRequest?, useMemoryCache: Bool?, animateInitialChange: Bool, animateDidLoadChange: Bool) {
		assert(Thread.isMainThread)
		
		guard let request = request else {
			setImage(nil, animated: animateInitialChange)
			return
		}
		
		let cacheKey = request.rlCacheKey
		if let currentlyLoadingCacheKey = currentSetImageTask?.cacheKey {
			guard currentlyLoadingCacheKey != cacheKey else {
				return
			}
			currentSetImageTask?.task.cancel()
			currentSetImageTask = nil
		}
		
		if let cacheKey = cacheKey, useMemoryCache ?? self.useMemoryCache, let image = Self.imagesCache.object(forKey: AnyHashableObject(cacheKey)) {
			return imageState.value = (.loadedImage(image), animateInitialChange)
		}
		
		imageState.value = (.loading(request), animateInitialChange)
		currentSetImageTask = (cacheKey, Task{
			assert(Thread.isMainThread) /* I don’t really know why that’s true though. */
			let download: Download
			if let cacheKey = cacheKey {
				if let d = Self.imagesDownloads[cacheKey] {
					download = d
					d.retain()
				} else {
					download = Download(request: request)
					Self.imagesDownloads[cacheKey] = download
				}
			} else {
				download = Download(request: request, forceCancelOnReleased: true)
			}
			await withTaskCancellationHandler(handler: {
				DispatchQueue.main.async{
					if download.release(), let cacheKey = cacheKey {
						Self.imagesDownloads[cacheKey] = nil
					}
				}
			}, operation: {
				do {
					let image = try await download.task.value
					if !Task.isCancelled {
						imageState.value = (.loadedImage(image), animateDidLoadChange)
					}
					if let cacheKey = cacheKey, useMemoryCache ?? self.useMemoryCache {
						Self.imagesCache.setObject(image, forKey: AnyHashableObject(cacheKey), cost: Int(image.size.width * image.size.height))
					}
				} catch {
					if !Task.isCancelled {
						imageState.value = (.loadingError(error), animateDidLoadChange)
					}
				}
				if let cacheKey = cacheKey, Self.imagesDownloads[cacheKey] === download {
					Self.imagesDownloads[cacheKey] = nil
				}
				currentSetImageTask = nil
			})
		})
	}
	
	private var currentSetImageTask: (cacheKey: AnyHashable?, task: Task<Void, Never>)?
	
	private static var imagesDownloads = [AnyHashable: Download]()
	private static var imagesCache = NSCache<AnyHashableObject, UIImage>()
	
	@MainActor
	private final class Download {
		
		var task: Task<UIImage, Error>
		let forceCancelOnReleased: Bool
		var refCount: Int
		
		init(request: RemoteImageViewRequest, forceCancelOnReleased: Bool = false) {
			self.refCount = 1
			self.forceCancelOnReleased = forceCancelOnReleased
			/* We use detached because we do _not_ want the operation to be cancelled when the parent task is cancelled,
			 *  as this task can be reused (for instance if another remote image view downloads the same URL). */
			self.task = Task.detached(priority: .low, operation: request.load)
		}
		
		func retain() {
			guard forceCancelOnReleased || Conf.defaultRemoteImageViewModelCancelsImageDownloadsWhenNoRemoteImageNeedsIt else {
				return
			}
			refCount += 1
		}
		
		func release() -> Bool {
			guard forceCancelOnReleased || Conf.defaultRemoteImageViewModelCancelsImageDownloadsWhenNoRemoteImageNeedsIt else {
				return false
			}
			
			assert(refCount > 0, "Over-release of a Download instance.")
			refCount -= 1
			if refCount <= 0 {
				task.cancel()
				return true
			}
			return false
		}
		
	}
	
	/** An objc-friendly wrapper for AnyHashable. */
	private final class AnyHashableObject : NSObject {
		
		let wrapped: AnyHashable
		
		init(_ anyHashable: AnyHashable) {
			self.wrapped = anyHashable
		}
		
		override var hash: Int {
			return wrapped.hashValue
		}
		
		override func isEqual(_ object: Any?) -> Bool {
			guard let other = object as? AnyHashableObject else {
				return false
			}
			return wrapped == other.wrapped
		}
		
	}
	
}

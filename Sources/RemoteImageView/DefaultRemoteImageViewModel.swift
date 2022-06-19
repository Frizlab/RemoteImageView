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
	
	public let urlSession: URLSession
	public let useMemoryCache: Bool
	
	public let animationDuration: TimeInterval
	
	public let imageState: CurrentValueSubject<(state: RemoteImageState, shouldAnimateChange: Bool), Never> = .init((.noImage, false))
	
	public init(
		urlSession: URLSession = RemoteImageViewConfig.defaultURLSession,
		useMemoryCache: Bool = RemoteImageViewConfig.defaultRemoteImageViewModelUsesMemoryCacheByDefault,
		animationDuration: TimeInterval = RemoteImageViewConfig.defaultAnimationDuration)
	{
		self.urlSession = urlSession
		self.useMemoryCache = useMemoryCache
		self.animationDuration = animationDuration
	}
	
	deinit {
		currentSetImageTask?.task.cancel()
		currentSetImageTask = nil
	}
	
	public func setImage(_ image: UIImage?, animated: Bool) {
		currentSetImageTask?.task.cancel()
		currentSetImageTask = nil
		
		imageState.send((image.flatMap{ .loadedImage($0) } ?? .noImage, animated))
	}
	
	public func setImageFromURLRequest(_ urlRequest: URLRequest?, useMemoryCache: Bool?, animateInitialChange: Bool, animateDidLoadChange: Bool) {
		assert(Thread.isMainThread)
		
		guard let urlRequest = urlRequest else {
			setImage(nil, animated: animateInitialChange)
			return
		}
		
		if let currentlyLoadingURL = currentSetImageTask?.url {
			guard currentlyLoadingURL != urlRequest.url else {
				return
			}
			currentSetImageTask?.task.cancel()
			currentSetImageTask = nil
		}
		
		guard let url = urlRequest.url else {
			/* We assume a URLRequest with no URL is invalid.
			 * I highly doubt there is a case where this is untrue, and we need the URL as it is our task dictionary key. */
			return imageState.send((.loadingError(RemoteImageViewError.noURLInRequest(urlRequest)), animateInitialChange))
		}
		if useMemoryCache ?? self.useMemoryCache, let image = Self.imagesCache.object(forKey: url as NSURL) {
			return imageState.send((.loadedImage(image), animateInitialChange))
		}
		
		imageState.send((.loading(urlRequest), animateInitialChange))
		currentSetImageTask = (url, Task{
			assert(Thread.isMainThread) /* I don’t really know why that’s true though. */
			let download: Download
			if let d = Self.imagesDownloads[url] {
				download = d
				d.retain()
			} else {
				download = Download(urlRequest: urlRequest)
				Self.imagesDownloads[url] = download
			}
			await withTaskCancellationHandler(handler: {
				DispatchQueue.main.async{
					if download.release() {
						Self.imagesDownloads[url] = nil
					}
				}
			}, operation: {
				do {
					let image = try await download.task.value
					if !Task.isCancelled {
						imageState.send((.loadedImage(image), animateDidLoadChange))
					}
					if useMemoryCache ?? self.useMemoryCache {
						Self.imagesCache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height))
					}
				} catch {
					if !Task.isCancelled {
						imageState.send((.loadingError(error), animateDidLoadChange))
					}
				}
				if Self.imagesDownloads[url] === download {
					Self.imagesDownloads[url] = nil
				}
				currentSetImageTask = nil
			})
		})
	}
	
	public func applyUIChanges(animatable: @MainActor @escaping () -> Void, cleanup: @MainActor @escaping () -> Void) {
		assert(Thread.isMainThread)
		UIView.animate(withDuration: Conf.defaultAnimationDuration, animations: { animatable() }, completion: { _ in cleanup() })
	}
	
	private var currentSetImageTask: (url: URL, task: Task<Void, Never>)?
	
	private static var imagesDownloads = [URL: Download]()
	private static var imagesCache = NSCache<NSURL, UIImage>()
	
	@MainActor
	private final class Download {
		
		var task: Task<UIImage, Error>
		var refCount: Int
		
		init(urlRequest: URLRequest) {
			self.refCount = 1
			
			let op = URLRequestDataOperation.forImage(urlRequest: urlRequest)
			/* We use detached because we do _not_ want the operation to be cancelled when the parent task is cancelled,
			 * as this task can be reused (for instance if another remote image view downloads the same URL). */
			self.task = Task.detached(priority: .low, operation: {
				try await withTaskCancellationHandler(
					operation: { try await op.startAsyncGetResult().result },
					onCancel: { op.cancel() }
				)
			})
		}
		
		func retain() {
			guard Conf.defaultRemoteImageViewModelCancelsImageDownloadsWhenNoRemoteImageNeedsIt else {
				return
			}
			refCount += 1
		}
		
		func release() -> Bool {
			guard Conf.defaultRemoteImageViewModelCancelsImageDownloadsWhenNoRemoteImageNeedsIt else {
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
	
}

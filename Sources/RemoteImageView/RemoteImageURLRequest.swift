/*
 * RemoteImageURLRequest.swift
 * CommonViews
 *
 * Created by François Lamboley on 2022/07/27.
 * Copyright © 2022 Togever. All rights reserved.
 */

import Foundation
import os.log
import UIKit

import HasResult
import OperationAwaiting
import URLRequestOperation



public struct RemoteImageURLRequest : Request, Hashable {
	
	public static func resizeDarkenAndBlurTransform(newSize: CGSize, contentMode: UIView.ContentMode = .scaleAspectFill, darkenAmount: CGFloat, blurRadius: CGFloat) -> ((UIImage) async -> UIImage, String) {
		let block = { (image: UIImage) -> UIImage in
			await withCheckedContinuation{ continuation in
				Conf.defaultRemoteImageViewModelImageParseQueue.async{
					guard let res = image
						.resized(to: newSize, contentMode: contentMode)
						.darkenedAndBlurred(darkenAmount: darkenAmount, blurRadius: blurRadius)
					else {
						Logger.view.error("Error darkening/blurring image. Returning original image.")
						return continuation.resume(returning: image)
					}
					continuation.resume(returning: res)
				}
			}
		}
		let identifier = "ResizeDarkenAndBlurTransform:\(newSize):\(contentMode):\(darkenAmount):\(blurRadius)"
		return (block, identifier)
	}
	
	public let urlRequest: URLRequest
	public let urlSession: URLSession
	
	public let transform: (block: (UIImage) async -> UIImage, identifier: String)?
	
	public init(urlRequest: URLRequest, transform: ((UIImage) async -> UIImage, String)? = nil, urlSession: URLSession = RemoteImageViewConfig.remoteImageViewModelDefaultURLSession) {
		self.urlRequest = urlRequest
		self.urlSession = urlSession
		
		self.transform = transform
	}
	
	public init(url: URL, transform: ((UIImage) async -> UIImage, String)? = nil, urlSession: URLSession = RemoteImageViewConfig.remoteImageViewModelDefaultURLSession) {
		self.init(urlRequest: URLRequest(url: url), transform: transform, urlSession: urlSession)
	}
	
	public var rlCacheKey: AnyHashable? {
		return self
	}
	
	public func load() async throws -> UIImage {
		let op = URLRequestDataOperation.forImage(urlRequest: urlRequest, session: urlSession, resultProcessingDispatcher: Conf.defaultRemoteImageViewModelImageParseQueue)
		let image = try await op.startAndGetResult().result
		return await transform?.block(image) ?? image
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(urlRequest.url)
		hasher.combine(transform?.identifier)
	}
	
	public static func ==(_ lhs: RemoteImageURLRequest, _ rhs: RemoteImageURLRequest) -> Bool {
		return lhs.urlRequest.url == rhs.urlRequest.url && lhs.transform?.identifier == rhs.transform?.identifier
	}
	
}

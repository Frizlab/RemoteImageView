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
import UIKit



@MainActor
public protocol RemoteImageViewModel {
	
	/**
	 The state of the image (loading, loaded, error, etc.).
	 
	 This property is effectively r/w even though it is `{get}` only because `CurrentValueSubject` is a class and its value can be changed.
	 The value should _not_ be changed manually though!
	 
	 TODO: Migrate to `AnyPublisher`, or something else.
	 Note we need to access the current image state, which an `AnyPublisher` do not give. */
	var imageState: CurrentValueSubject<(state: RemoteImageState, shouldAnimateChange: Bool), Never> {get}
	
	func setFakeLoading(animated: Bool)
	func setImage(_ image: UIImage?, animated: Bool)
	func setImageFromURLRequest(_ urlRequest: URLRequest?, useMemoryCache: Bool?, animateInitialChange: Bool, animateDidLoadChange: Bool)
	
	/**
	 Called by the remote image view when it updates its internal views, when animations can be expected.
	 
	 If you want to animate the changes (fade from loading view to loaded image for instance),
	 simply call the `animatable` block in an `UIView.animate` call.
	 You can animate other views of your own in parallel if you want.
	 
	 Use the `transition` parameter to determine what kind of transition you want to do.
	 
	 The `cleanup` block must be called when the animation is over.
	 
	 - Important: Changing the state of a ``RemoteImageView`` from showing an image to showing another image will _not_ be animated. */
	func applyUIChanges(animatable: @MainActor @escaping () -> Void, cleanup: @MainActor @escaping () -> Void)
	
}


public enum RemoteImageState {
	
	/**
	 No image set in the remote image view, with a parameter to specify the remote image view should show the loading view instead of the nil one.
	 
	 When loading a view, you might be waiting for some data from a back-end to know the URL to display in your remote image view.
	 The image view should usually show the loading view instead of the nil one while the URL is unknown.
	 This is an example of when to set `fakeLoading` to true. */
	case noImage(fakeLoading: Bool)
	
	case loading(URLRequest)
	case loadedImage(UIImage)
	case loadingError(Error)
	
}

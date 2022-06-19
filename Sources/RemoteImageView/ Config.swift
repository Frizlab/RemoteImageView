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



public enum RemoteImageViewConfig {
	
	public static var loggerSubsystem = "me.frizlab.remote-image-view"
	
	/** The default animation duration in the default remote image view model. */
	public static var defaultAnimationDuration: TimeInterval = 0.25
	
	/** The default session to use for networking in the default remote image view model. */
	public static var defaultURLSession: URLSession = .shared
	
	/**
	 Whether the default remote image view model cancels the image downloads if no remote image views are showing the URL being downloaded.
	 
	 When a remote image view is asked to show a given URL, it will ask its view model to load the given URL.
	 The view model will first check its cache, it the image is in it, it will return it directly.
	 If not, it will check the currently loading images.
	 If there is a loading operation for the given URL, it will await for its result and then return it.
	 If not, it will start the loading operation, await its result and return it.
	 
	 While the URL is loading, the image view can ask its view model to show a different URL.
	 
	 The `defaultRemoteImageViewModelCancelsImageDownloadsWhenNoRemoteImageNeedsIt` variable controls what happens
	 when all of the remote image view using the default view model cancels loading an URL (by asking to show another URL, or other).
	 
	 The default behaviour (variable set to `false`) will _not_ stop downloading the images, even if no remote image views are using it.
	 The rationale for this is:
	 - Starting a TCP connection is expensive;
	 - Another remote image view might need the URL later.
	 
	 So we keep loading the image and put it in the cache for a later use.
	 
	 When setting the variable to `true`, the loading will be cancelled as soon as no image view need the URL being loaded. */
	public static var defaultRemoteImageViewModelCancelsImageDownloadsWhenNoRemoteImageNeedsIt = false
	
	/** Set to false to not use a memory cache for the given images. */
	public static var defaultRemoteImageViewModelUsesMemoryCacheByDefault = true
	
}

typealias Conf = RemoteImageViewConfig

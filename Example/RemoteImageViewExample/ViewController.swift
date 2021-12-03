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

import UIKit

import RemoteImageView



class ViewController: UIViewController {
	
	@IBOutlet var remoteImageView: RemoteImageView!
	@IBOutlet var nilView: UIView!
	
	@IBOutlet var textField: UITextField!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		/* Set nil view from storyboard loaded view.
		 * Important: The view’s layout must be set to inferred (use constraints) in the Storyboard.
		 * Also note: Apparently the storyboard does not care if this is set and returns the view with the autoresizing contraints… */
		nilView.translatesAutoresizingMaskIntoConstraints = false
		remoteImageView.viewNil = nilView
		/* Or manually create views. */
		remoteImageView.viewLoading = UIView(noAutoresizeWithFrame: remoteImageView.bounds, backgroundColor: .lightGray)
		remoteImageView.viewError = UIView(noAutoresizeWithFrame: remoteImageView.bounds, backgroundColor: .red)
	}
	
	@IBAction func tappedRandomButton(_ sender: Any?) {
		remoteImageView.setImageFromURL(
			URL(string: "https://random.imagecdn.app/\(Int(remoteImageView.frame.width))/\(Int(remoteImageView.frame.height))")!,
			useMemoryCache: false
		)
	}
	
	@IBAction func tappedUseTextField(_ sender: Any?) {
		remoteImageView.setImageFromURL(URL(string: textField.text ?? ""))
	}
	
}

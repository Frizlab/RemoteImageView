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
import UIKit

import RemoteImageView



class ViewController: UIViewController {
	
	@IBOutlet private var remoteImageView: RemoteImageView!
	@IBOutlet private var nilView: UIView!
	
	@IBOutlet private var labelState: UILabel!
	@IBOutlet private var textField: UITextField!
	
	@IBOutlet private var switchDarkenAndBlur: UISwitch!
	
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
		
		remoteImageView.viewModel.imageState
			.map{ state in
				switch state {
					case let (.loadedImage,       animated): return "\(animated ? "→ " : "")Loaded"
					case let (.loading,           animated): return "\(animated ? "→ " : "")Loading…"
					case let (.loadingError,      animated): return "\(animated ? "→ " : "")Error"
					case let (.noImage(fakeLoad), animated): return "\(animated ? "→ " : "")\(fakeLoad ? "Fake Loading…" : "No Image")"
				}
			}
			.assign(to: \.text, on: labelState)
			.store(in: &observers)
		
		if textField.text?.isEmpty ?? true {
			tappedRandomButton(nil)
		} else {
			tappedUseTextField(nil)
		}
	}
	
	private static let udKeyLatestURL = "FRZ - RemoteImageViewExample - LatestURL"
	private static let udKeyDarkenAndBlur = "FRZ - RemoteImageViewExample - UseDarkenAndBlur"
	
	private var observers = Set<AnyCancellable>()
	
	@IBAction private func switchedDarkenAndBlur(_ sender: Any?) {
		UserDefaults.standard.set(switchDarkenAndBlur.isOn, forKey: Self.udKeyDarkenAndBlur)
		tappedUseTextField(nil)
	}
	
	@IBAction private func tappedRandomButton(_ sender: Any?) {
		setURL(
			URL(string: "https://random.imagecdn.app/\(Int(remoteImageView.frame.width))/\(Int(remoteImageView.frame.height))")!,
			useMemoryCache: false
		)
	}
	
	@IBAction private func tappedUseTextField(_ sender: Any?) {
		setURL(URL(string: textField.text ?? ""))
	}
	
	private func setURL(_ url: URL?, useMemoryCache: Bool = true) {
		if let url = url {
			remoteImageView.setImageFromRequest(
				RemoteImageURLRequest(
					urlRequest: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData),
					transform: switchDarkenAndBlur.isOn ? RemoteImageURLRequest.resizeDarkenAndBlurTransform(newSize: remoteImageView.bounds.size, darkenAmount: 0.5, blurRadius: 8) : nil
				),
				useMemoryCache: useMemoryCache,
				animateInitialChange: true,
				animateDidLoadChange: true
			)
			textField.text = url.absoluteString
			UserDefaults.standard.set(url, forKey: Self.udKeyLatestURL)
		} else {
			remoteImageView.setImage(nil)
		}
	}
	
}

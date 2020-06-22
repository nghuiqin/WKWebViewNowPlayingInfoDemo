//
//  WebViewController.swift
//  iOSNowPlayingInfoWKWebView
//
//  Created by Hui Qin Ng on 2020/6/22.
//  Copyright © 2020 Hui Qin Ng. All rights reserved.
//

import UIKit
import WebKit

final class WebViewController: UIViewController {
	private let webView = WKWebView(frame: .zero)

	override func loadView() {
		super.loadView()
		view.addSubview(webView)
		webView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
		])
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		guard let url = URL(string: "https://www.youtube.com") else { return }
		webView.load(URLRequest(url: url))
    }
}

//
//  ViewController.swift
//  iOSNowPlayingInfoWKWebView
//
//  Created by Hui Qin Ng on 2020/6/22.
//  Copyright © 2020 Hui Qin Ng. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer.MPNowPlayingInfoCenter

final class ViewController: UIViewController {

	private let playButton = UIButton(type: .custom)
	private let player = AVPlayer()

	override func loadView() {
		super.loadView()
		view.addSubview(playButton)
		playButton.setTitleColor(.blue, for: .normal)
		playButton.setTitle("Play", for: .normal)
		playButton.addTarget(self, action: #selector(onPlayButtonClicked(sender:)), for: .touchUpInside)

		playButton.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
		])

		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(onBarItemClicked(sender:)))

		guard let url = URL(string: "https://feeds.soundcloud.com/stream/786018733-daodutech-heros-emerge-in-troubled-times.mp3") else { return }
		player.replaceCurrentItem(with: AVPlayerItem(url: url))
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}
}

@objc extension ViewController {
	func onPlayButtonClicked(sender: Any?) {
		func registerMPNowPlayingInfo() {
			MPNowPlayingInfoCenter.default().nowPlayingInfo = [
				MPMediaItemPropertyTitle: "Hello Test",
				MPMediaItemPropertyArtist: "I'm artist",
				MPMediaItemPropertyAlbumTitle: "This is album"
			]
		}

		func registerMPRemoteCommand() {
			MPRemoteCommandCenter.shared().playCommand.addTarget { [player] _ -> MPRemoteCommandHandlerStatus in
				player.play()
				return .success
			}

			MPRemoteCommandCenter.shared().pauseCommand.addTarget { [player] _ -> MPRemoteCommandHandlerStatus in
				player.pause()
				return .success
			}
		}

		try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
		try? AVAudioSession.sharedInstance().setActive(true)
		registerMPRemoteCommand()
		registerMPNowPlayingInfo()
		player.play()
	}

	func onBarItemClicked(sender: Any?) {
		let webViewController = WebViewController()
		navigationController?.pushViewController(webViewController, animated: true)
	}
}


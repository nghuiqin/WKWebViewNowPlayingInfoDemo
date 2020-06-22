//
//  HomeViewController.swift
//  MacPlayer
//
//  Created by Hui Qin Ng on 2019/9/2.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import Cocoa
import KKAudioEngine
import MediaPlayer
import AVFoundation
import WebKit

class HomeViewController: NSViewController {

	@IBOutlet weak var webView: WKWebView!
	private var engine: KKAudioEngine = KKAudioEngine()
	let youtubeURL = URL(string: "https://www.youtube.com")!

    override func viewDidLoad() {
        super.viewDidLoad()

		DispatchQueue.global(qos: .background).async {
			if #available(OSX 10.12.2, *) {
				self.updateMPRemoteControlCenter()
			}
		}
		webView.load(URLRequest(url: youtubeURL))
    }
    
	@IBAction func playAction(_ sender: Any) {
		webView.load(URLRequest(url: youtubeURL))
		engine.delegate = self
		let songURL = URL(string:"https://zonble.net/MIDI/orz.mp3")!
		engine.loadAudio(with: songURL, suggestedFileType: kAudioFileMP3Type, contextInfo: nil)
		if #available(OSX 10.12.2, *) {
			MPNowPlayingInfoCenter.default().nowPlayingInfo = [
				MPMediaItemPropertyTitle: "Testing MacPlayer",
				MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
				MPMediaItemPropertyPlaybackDuration: 0,
				MPNowPlayingInfoPropertyPlaybackRate: 1.0
			]
		}
		engine.play()
	}

	@IBAction func pauseAction(_ sender: Any) {
		engine.pause()
	}
}


extension HomeViewController: KKAudioEngineDelegate {
	func audioEngineWillStartPlaying(_ audioEngine: KKAudioEngine) {}

	func audioEngineDidStartPlaying(_ audioEngine: KKAudioEngine) {}

	func audioEngineDidPausePlaying(_ audioEngine: KKAudioEngine) {}

	func audioEngineDidStall(_ audioEngine: KKAudioEngine) {}

	func audioEngineDidEndCurrentPlayback(_ audioEngine: KKAudioEngine) {}

	func audioEngineDidEndPlaying(_ audioEngine: KKAudioEngine) {}

	func audioEngineDidHaveEnoughData(toStartPlaying audioEngine: KKAudioEngine) {}

	func audioEngineDidHaveEnoughData(toResumePlaying audioEngine: KKAudioEngine) {}

	func audioEngineDidCompleteLoading(_ audioEngine: KKAudioEngine) {}

	func audioEngine(_ audioEngine: KKAudioEngine, didFailLoadingWithError error: Error) {}

	func audioEngine(_ audioEngine: KKAudioEngine, didFailLoadingNextAudioWithError error: Error, contextInfo: Any?) {}

	func audioEngine(_ audioEngine: KKAudioEngine, updateCurrentPlaybackTime currentTime: TimeInterval, loadedDuration: TimeInterval) {
		if #available(OSX 10.12.2, *) {
			let info: [String: Any] = [
				MPMediaItemPropertyTitle: "Testing",
				MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
				MPMediaItemPropertyPlaybackDuration: loadedDuration,
				MPNowPlayingInfoPropertyPlaybackRate: 1.0
			]
			MPNowPlayingInfoCenter.default().nowPlayingInfo = info as [String : Any]
		}
	}
}

@available(OSX 10.12.2, *)
private extension HomeViewController {
	func updateMPRemoteControlCenter() {
		let commandCenter = MPRemoteCommandCenter.shared()
		commandCenter.playCommand.isEnabled = true
		commandCenter.playCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
			self?.engine.play()
			return .success
		}

		commandCenter.pauseCommand.isEnabled = true
		commandCenter.pauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
			self?.engine.pause()
			return .success
		}

		commandCenter.togglePlayPauseCommand.isEnabled = true
		commandCenter.togglePlayPauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
			guard let self = self else {
				return .commandFailed
			}
			self.engine.isPlaying ? self.engine.pause() : self.engine.play()
			return .success
		}
	}
}

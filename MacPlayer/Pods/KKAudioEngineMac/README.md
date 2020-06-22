# KKAudioEngineMac

Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.

## 簡介

KKAudioEngineMac 是 KKBOX 的 iOS/Mac OS X 部門，在 2014 年所開發的一套供 macOS 平台使用的 audio 播放元件。這套元件的重點在－

- 可支援無縫播放
- 可支援 Crossfade
- 使用 Audio Unit API 開發
- 可播放各種 Core Audio API 所支援的格式，包括 KKBOX 所使用的 MP3 與 AAC-ADTS。
- 可播放像 MP3 網路廣播這類無限長度的網路音訊
- 可使用暫存檔儲存 packet，避免瞬間載入大量實體記憶體
- 預設支援 HTTP stream 與本機檔案
- 架構上保留接口，可擴充其他抓取檔案播放的方式
- 架構上保留接口，可擴充像是 EQ 等化器等 Audio Filter

如果有任何問題，請洽 KKBOX 的 iOS/Mac OS X 部門。

## 系統需求

- Mac OS X 10.7 以上作業系統
- 只支援 64 位元環境
- Xcode 4.4 以上（我們使用了大量的新 Objective-C literal 與省略 synthesize 的語法）
- 必須使用 ARC 記憶體管理

## 安裝

這個套件可以使用 [CocoaPods](https://cocoapods.org) 安裝，您可以在 Podfile 中加上這行：

```ruby
pod 'KKAudioEngineMac', :git => 'git@gitlab.kkinternal.com:kkbox-ios/kkaudioenginemac.git'
```

或是使用 KKBOX 內部的 Git Spec repo。先在 Command Line 底下執行

```
pod repo add KKBOXPodSpecs git@gitlab.kkinternal.com:xddd/kkboxpodspecs.git

```

然後在 Podfile 中增加

```ruby
source 'https://github.com/CocoaPods/Specs.git'
source 'git@gitlab.kkinternal.com:xddd/kkboxpodspecs.git'

pod 'KKAudioEngineMac'
```

## 使用方式

本專案包含範例程式，放在 Examples 目錄下，可以參考當中如何使用 KKAudioEngineIOS。

從外部要使用這個播放元件播放資料的時候，通常只需要透過 `KKAudioEngine` 這個 facade。`KKAudioEngine` 現在提供播放 HTTP Server 與本機音檔兩種方式，但基本上只需要傳入 `NSURL` 物件與音檔格式即可，`NSURL` 物件代表遠端或本機的檔案 URL。例如

```objc
engine = [[KKAudioEngine alloc] init];
[engine loadAudioWithURL:[NSURL URLWithString:@"http://zonble.net/MIDI/orz.mp3"]
```

接下來播放時發生的事件，會回傳到 `KKAudioEngine` 的 delegate 上。開始播放之後，我們可以從 `KKAudioEngine` 的 `playingContinuousStream` 得知是否是網路廣播，也可以用各種屬性知道歌曲長度、載入進度，以及調整播放時間。

### 使用無縫播放功能

要實作無縫播放的方法是，我們可以在任何時間，指定在播完目前的歌曲後，接下來應該要播放什麼，那麼，在目前歌曲結束後，就會開始播放下一首歌。方法是：

```objc
[engine loadNextAudioWithURL:[NSURL URLWithString:@"http://zonble.net/MIDI/orz.mp3"] suggestedFileType:kAudioFileMP3Type contextInfo:nil];
```

請注意：重複呼叫 `loadNextAudioWithURL:suggestedFileType:`，效果是會把指定的下一首歌曲換掉，而不是繼續排到後面，`KKAudioEngine` 裡頭只會同時有「現在這首歌」與「下一首歌」，並不是一個 play queue。我們可以在目前歌曲快要播放結束時這類時機，指定下一首歌。

### 使用 Crossfade（淡入/淡出）功能

如果已經指定了下一首歌曲，我們還可以指定要求播放器使用 crossfade，讓兩首歌之間產生淡入淡出效果，方法是指定 crossfadeDuration 參數，單位是秒。像是：

```objc
engine.crossfadeDuration = 10.0;
```

在這邊的程式碼中，還不包含如何播放 KKBOX 歌曲的部分。請參考文件中 [如何擴充 KKAudioOperation](#kkaudiooperation) 部分。

## 開發背景

KKBOX Mac 版本從 2008 年開始開發，隨著幾年的時間過去，KKBOX 的商業模式隨著改變，超過了最初設計時的想像，原本的 audio 播放元件—LFMP3—的缺陷也逐漸暴露出來。包括：

- 當初 KKBOX Mac 版本只支援 MP3 格式，但是在 2013 年上半年推出高音質服務之後，KKBOX 也開始提供 320k AAC-ADTS 格式的檔案。我們雖然想辦法讓 LFMP3 也能夠播放 AAC-ADTS，但是後來加入的程式碼，缺乏設計上的整體感。
- 在 2014 年預計推出無縫播放模式，原本的架構也不適合。
- 在 2014 年下半年，KKBOX 預計推出 Freemium 服務，影響是，KKBOX 不但會用來播放歌曲，也會需要播放歌曲之間的插播廣告，原本的設計也沒考慮這種情境。
- LFMP3 在串連 audio graph 中的每個 node 的程式碼非常混亂，在 2014 年時，看起來也已經變得不好維護。

我們在重構與撰寫新的 audio 元件之間做了一些掙扎，後來決定試試看寫新的元件…結果就寫出來了。在這個架構中，我們甚至可以做到「讓 KKBOX 的歌曲與廣告之間也可以無縫播放」。

## 程式架構

從 KKBOX Mac 版本一開始，我們就將「怎樣抓取資料與抓到多少資料可以播放」與「如何呼叫底層的 Audio API 播放資料」分成兩個部分，在過去幾次的實作中，我們通常將前者稱為 **stream player**，後者叫做 **data player**，data player 是 stream player 的成員，外部通常只操作 stream player，而不會碰到 data player。

在這一次的實作中，與過去的最大差別，在於我們將 audio converter 從 data player 移到上層，新的 data player 叫做 `KKAudioGraph`，`KKAudioGraph` 直接接收 Linear PCM 格式的資料，而不再負責將 MP3、AAC 轉換成 Linear PCM 的工作。

過去讓 data player 負責轉換檔案的最大問題，出在如果前一首歌曲與下一首歌曲的檔案格式不同，那麼就必須建立新的 `AudioConverterRef`，而過去的架構中，把建立 `AudioConverterRef` 所需要的檔案格式資訊，設計成建立 data player 時的基本參數，data player 建立後就無法改變，導致必須要移除原本的 data player 重建，這件事情會造成無法無縫播放。

`KKAudioEngine` 這個 Class 相當於過去 stream player 的角色，但是這個 stream player 並不自己負責抓取資料，而是將抓取資料的工作包裝成一個 opertation — `KKAudioEngineOperation`。 `KKAudioEngineOperation` 當中包含抓取資料、Parse Packet（透過成員中的`KKAudioStreamParser`）、儲存 Packet（存在 `KKAudioStreamBuffer` 中），以及將資料轉成 Linear PCM 格式。

`KKAudioEngine` 同時是 `KKAudioEngineOperation` 與 `KKAudioGraph` 的 delegate，負責兩者的中介，當 `KKAudioGraph` 需要可以播放的資料時，`KKAudioEngine` 提供 `KKAudioGraph` 目前正在工作中的 operation 並向它要求轉換好的 Linear PCM 資料。至於 `KKAudioEngineOperation` 當中發生了事件，像是有足夠資料可以播放等，也是透過 `KKAudioEngine` 控制 `KKAudioGraph`。

### 無縫播放

無縫播放的原理是，當我們正在播放現在的這首歌曲的時候，已經開始嘗試載入下一首歌曲的資料；因此我們可以看到，在 KKAudioEngine 中，有 currentOperation 與 nextOperation 兩個變數，在 currentOperation 還在執行，將資料餵給 audio graph 播放時，我們就可以先建立 nextOperation，等到 currentOperation 結束時，我們便可以直接把已經載入好資料的 nextOperation 接上來，把 nextOperation 指向 currentOperation 後開始提供 audio graph 資料，於是我們便省下了播放下一首歌曲時所需要的載入時間。

### Crossfade（淡入/淡出）

我們的 audio graph 中有一個負責混音的 mixer node，連接兩個 bus，平常 currentOperation 會將資料送到 bus 0。當 currentOperation 發現自己的播放時間差不多到底，就會要求 KKAudioEngine 把 currentOperation 變成 previousOperation，把 nextOperation 變成 currentOperation，previousOperation 就會把資料送到 bus 1，如此一來，bus 0 與 bus 1 就會同時發出聲音，就會出現同時播放兩首歌曲的效果。

我們這時候會嘗試將 bus 0 的音量設成 0， bus 1 則是 1，然後將 bus 1 的音量慢慢變小，bus 0 則慢慢變大，就產生了兩首歌曲交疊，並且相互淡入/淡出的效果。

## 如何擴充 KKAudioEngineMac

KKAudioEngineMac 考慮了未來的一定擴充性。主要保留的擴充接口在於增加新的抓取檔案方式，以及方便增加各種效果；方法是透過繼承 `KKAudioOperation` 與 `KKAudioNode`。

### 擴充 KKAudioOperation

<a id=kkaudiooperation></a>

這邊的程式碼還不包含實際播放 KKBOX 歌曲的部分。要實作播放 KKBOX 歌曲，我們可以透過繼承 `KKAudioOperation`，將 KKBOX 的播放流程—先取 ticket，取完 ticket 之後決定要播放已下載音檔或線上音檔、DRM 加解密—等等，包裝成一個 operation。

由於 `KKAudioEngine`只辨識 `KKAudioOperation` 上層的接口，只要繼承 `KKAudioOperation` 便可以播放，因此支援各種抓取檔案的方式，而且讓這些不同來源的 operation 無縫播放。

### 擴充 KKAudioNode

在 `KKAudioGraph` 這個 class 中，我們將 audio graph 裡頭如何串接 `AUNode` 的步驟，用 Objective-C 物件封裝起來—Core Audio 所提供的 C API 實在非常繁瑣而且難懂。我們目前實作了最基本的 output node，以及一個 EQ effect node。

如果還想要擴充其他的 audio effect，core audio 還有很多不同的 effect node 可以使用（參見 _[Audio Unit Component Services Reference](https://developer.apple.com/library/mac/documentation/AudioUnit/Reference/AUComponentServicesReference/Reference/reference.html)_ 中 Effect Audio Unit Subtypes 部分），我們可以選擇要使用的 effect node，包裝成 `AUNode` 物件，並且把這個 `AUNode` 放進 audio graph 中。

在 `KKAudioGraph` 的 `init:` method 中有這一段：

```objc
self.EQEffectNode = [[KKAudioEQEffectNode alloc] initWithAudioGraph:audioGraph];
...
[self connectNodes:@[self.subgraph, self.EQEffectNode, self.outputNode]];
```

這段程式的用意是，在這個 audio graph 中建立新的 effect node，接著將所有用到的 node 串接起來。如果你有新的 effect node，將程式插入到這邊即可。

### 其他擴充方式

我們曾經在 KKBOX 中實作過 spectrum 頻譜圖效果，後來因為產品設計改變所以拿掉了。不過，如果我們接下來還想實作 spectrum，可以從 `KKAudioEngine` 中 `audioGraph:requestNumberOfFrames:ioData:busNumber:` 這個 method 的實作下手。

實作 spectrum 的原理是，我們在拿到 Linear PCM 資料之後，對 Linear PCM 資料做 FFT，接著把 FFT 的結果顯示在畫面上。前面提到的 method 就是 `KKAudioGraph` 跟 operation 取得 Linear PCM 資料的接口，我們可以從 `inIoData` 中拿到要做 FFT 的資料。我們也可以在這邊透過直接改動 Linear PCM 資料，改變要播放的內容。

## FAQ

### KKBOX 為什麼不使用更高階的 Player，像是 AVFoundation 裡頭的 [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer)？

因為這樣沒辦法實作 KKBOX 自己的 DRM。AVPlayer 只支援蘋果自己的 [Fair Play](https://developer.apple.com/streaming/fps/)。

### KKBOX 為什麼不使用 [AVAudioEngine](https://developer.apple.com/documentation/avfoundation/avaudioengine)？

我們在開發 KKAudioEngine 的時候，還必須支援 iOS 8 以下的版本，而要在 iOS 8 以上才能使用 AVAudioEngine。

### KKBOX 為什麼不使用 [Audio Queue](https://developer.apple.com/documentation/audiotoolbox/audio_queue_services) API？

我們的確一度使用 Audio Queue API 實作 audio 播放元件，不過，因為我們後來希望能夠做像是 EQ 等化器等功能，但是用 Audio Queue API 做不到。

我們在 KKAudioEngine 的架構中，透過呼叫 Audio Unit API，會比使用 Audio Queue API，在播放時間上有更好的控制。Audio Queue 的基本作法是建立好一個一定長度（通常是若干秒）的 buffer 後，丟到 Audio Queue 中播放，我們最多只能夠知道從哪個位置建立了 buffer，但是播到 buffer 中的哪個精確的時間卻無法控制。但是在 KKAudioEngine 中，我們可以知道現在到底播放到哪個 packet，以 MP3 或 AAC 來說，最小的播放時間間隔大概到 0.025 秒左右。

### KKBOX 的 Mac 與 iOS 版本為什麼不共用 Audio 播放元件？

我們在 iOS 版本中有一套比較新的元件 KKAudioContent，原本以為讓 Mac 與 iOS 版本共用同一個元件，避免維護兩份播放元件的問題。但是—

Mac 與 iOS 在 Audio Unit API 的底層就不一樣，包括 Mac 可以使用 subgraph 但是 iOS 沒有，iOS 用的 output node 是 remote IO 與 Mac 也不同，可以使用的 effect node 也不同，光是要讓同一個 player 可以同時在 iOS 與 Mac OS X 上可以用，就要寫一堆 macro 區隔。

iOS 上有背景播放問題。iOS 版本中為了可以在背景時也可以使用「一起聽」功能，做了一大堆即使沒有在播放音訊，也要佔用 audio 硬體的 workaround。Mac 版本並不需要這樣的設計，將這樣的東西放在 Mac 上，反倒讓 Mac 版本日後難以維護。

但更大的問題是，Mac 與 iOS 版本的商業邏輯不同：

- Mac 版還是要在播放每首歌曲之前先取 ticket，但是 iOS 版本則在有下載音檔的時候先播放已下載的音檔，之後才取 ticket 這種邏輯。
- Mac 版本中「下載音檔」與 Cache 是分開的，但是 iOS 版本並沒有 Cache，但是卻有「邊聽邊下載」這樣的機制。

在商業邏輯不一樣的狀況下，勉強要讓兩個平台共用播放元件，對兩個平台看起來都不健康。但另一方面，KKAudioEngineMac 也用了不少來自 KKAudioContent 的程式碼。

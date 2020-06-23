# WKWebViewNowPlayingInfoDemo

### This problem is happened on iOS

In sample app, we register remote command and nowPlayingCenter when tap on play button.
First, we will successfully register information on NowPlayingInfoCenter. 
However, when wkwebview is opened and played any youtube content, NowPlayingInfoCenter information will be changed.
But, we couldn't register it back when webview is closed until we kill app and relaunch.

![](https://media.giphy.com/media/TjYckLokNsMt5RQfai/giphy.gif)


### MacPlayer
MacOS will able to register NowPlayingInfoCenter back while webView reload to youtube homepage or closed.

## Response from Apple Engineer
This is a bug but already fixed recently. [Bug ticket](https://bugs.webkit.org/show_bug.cgi?id=211899)
But not yet available to recent Webkit framework.
Workaround solution is calling some private apis which is not recommended.

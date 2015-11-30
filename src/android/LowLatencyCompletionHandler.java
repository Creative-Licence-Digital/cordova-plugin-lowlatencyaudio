package com.rjfun.cordova.plugin;



public interface LowLatencyCompletionHandler {

	void onFinishedPlayingAudio(String status);
	void onProgress(float progress);

}

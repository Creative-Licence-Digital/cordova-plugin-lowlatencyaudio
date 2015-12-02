/*
THIS SOFTWARE IS PROVIDED BY ANDREW TRICE "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL ANDREW TRICE OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

package com.rjfun.cordova.plugin;

import java.io.IOException;
import java.util.Timer;
import java.util.TimerTask;

import android.content.res.AssetFileDescriptor;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnPreparedListener;
import android.util.Log;

public class PolyphonicVoice implements OnPreparedListener, OnCompletionListener {

	private static final int INVALID = 0;
	private static final int PREPARED = 1;
	private static final int PENDING_PLAY = 2;
	private static final int PLAYING = 3;
	private static final int PENDING_LOOP = 4;
	private static final int LOOPING = 5;

	private MediaPlayer mp;
	private int state;
	private float currentProgress = 0;
	private float volume; // Volume that this audio is initialized with
	private float targetVolume; // Used internally to fadeIn and fadeOut
	private float currentVolume; // Used internally to fadeIn and fadeOut

	private LowLatencyCompletionHandler savedHandler;

	public PolyphonicVoice( AssetFileDescriptor afd, float volume)  throws IOException
	{
		mp = new MediaPlayer();
		mp.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
		this.volume = volume;
		this.configureMediaPlayer(volume);
	}

	public PolyphonicVoice( String filePath, float volume)  throws IOException
	{
		mp = new MediaPlayer();
		mp.setDataSource(filePath);
		this.volume = volume;
		this.configureMediaPlayer(volume);
	}

	private void configureMediaPlayer(float volume) throws IOException
	{
		state = INVALID;
		mp.setAudioStreamType(AudioManager.STREAM_MUSIC);
//		mp.setVolume(volume, volume);
		mp.prepare();
		mp.setOnCompletionListener(new OnCompletionListener() {
			@Override
			public void onCompletion(MediaPlayer mp) {
				if (savedHandler != null) {
					savedHandler.onFinishedPlayingAudio("PLAY FINISHED");
				}
			}
		});
	}

	public void play() throws IOException
	{
		invokePlay(false);
		updateProgress();
	}

	private void invokePlay( Boolean loop, Boolean fadeIn, final float fadeDuration, final float increment )
	{
		Boolean playing = ( mp.isLooping() || mp.isPlaying() );
		if ( playing )
		{
			mp.pause();
			mp.setLooping(loop);
			mp.seekTo(0);

			if (fadeIn) {
				invokeFadeIn(increment, fadeDuration);
			} else {
				mp.start();
			}
		}
		if ( !playing && state == PREPARED )
		{
			state = PENDING_LOOP;
			onPrepared(mp);
		}
		else if ( !playing )
		{
			state = PENDING_LOOP;
			mp.setLooping(loop);

			if (fadeIn) {
				invokeFadeIn(increment, fadeDuration);
			} else {
				mp.setVolume(volume, volume);
				mp.start();
			}
		}
	}

	private void invokeFadeIn(final float increment, float fadeDuration) {
		mp.setVolume(0, 0);
		mp.start();

		int delay = (int) (increment * fadeDuration);
		final Timer timer = new Timer();
		targetVolume = volume;
		timer.schedule(new TimerTask() {
			@Override
			public void run() {
				if (currentVolume < targetVolume) {
					if (currentVolume + increment > 1) {
						currentVolume = 1;
					} else {
						currentVolume += increment;
					}
					mp.setVolume(currentVolume, currentVolume);
				} else {
					timer.cancel();
				}
			}
		}, 0, delay);
	}

	private void invokePlay(Boolean loop) {
		invokePlay(loop, false, 0, 0);
	}

	public void stop() throws IOException
	{
		if ( mp.isLooping() || mp.isPlaying() )
		{
			state = INVALID;
			mp.pause();
			this.currentVolume = 0;
			mp.seekTo(0);
		}
	}

	public void loop() throws IOException
	{
		invokePlay(true);
	}

	public void fadeIn(float fadeDuartion, float increment) throws IOException
	{
		invokePlay(true, true, fadeDuartion, increment);
	}

	public void fadeOut(float fadeDuration, final float increment) throws IOException
	{
		if (mp.isLooping() || mp.isPlaying()) {
			this.targetVolume = 0;
			final PolyphonicVoice SELF = this;
			int delay = (int) (increment * fadeDuration);

			final Timer timer = new Timer();
			timer.schedule(new TimerTask() {
				@Override
				public void run() {
					if (currentVolume > targetVolume) {
						if (currentVolume - increment < 0) {
							currentVolume = 0;
						} else {
							currentVolume -= increment;
						}
						mp.setVolume(currentVolume, currentVolume);
					} else {
						state = INVALID;
						mp.pause();
						currentVolume = 0;
						mp.seekTo(0);

						timer.cancel();
						timer.purge();
					}
				}
			}, 0, delay);
		}
	}

	public void unload() throws IOException
	{
		this.currentVolume = 0;
		this.stop();
		mp.release();
	}

	public void updateProgress() {
		Log.d("LowLatencyAudio", "progress " + mp.getCurrentPosition() + " " + mp.getDuration());
		float progress = mp.getCurrentPosition() / mp.getDuration();
		// Deal with the Android bug: https://code.google.com/p/android/issues/detail?id=38627
		if (mp.getDuration() - mp.getCurrentPosition() > 1000 && progress < 1.0) {
			currentProgress = progress;

			savedHandler.onProgress(currentProgress);
			Timer timer = new Timer();
			timer.schedule(new TimerTask() {
				@Override
				public void run() {
					updateProgress();
				}
			}, 500);
		}
	}

	public void onPrepared(MediaPlayer mPlayer)
	{
		if (state == PENDING_PLAY)
		{
			mp.setLooping(false);
			mp.seekTo(0);
			mp.start();
			state = PLAYING;
		}
		else if ( state == PENDING_LOOP )
		{
			mp.setLooping(true);
			mp.seekTo(0);
			mp.start();
			state = LOOPING;
		}
		else
		{
			state = PREPARED;
			mp.seekTo(0);
		}
	}

	public void onCompletion(MediaPlayer mPlayer)
	{
		if (state != LOOPING)
		{
			this.state = INVALID;
			try {
				this.stop();
			}
			catch (Exception e)
			{
				e.printStackTrace();
			}
		}
	}

	public void setComplectionHandler(LowLatencyCompletionHandler complectionHandler) {
		this.savedHandler = complectionHandler;
	}
}

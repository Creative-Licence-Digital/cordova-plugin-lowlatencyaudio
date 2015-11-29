//
//  LowLatencyAudioAsset.m
//  LowLatencyAudioAsset
//
//  Created by Andrew Trice on 1/23/12.
//
// THIS SOFTWARE IS PROVIDED BY ANDREW TRICE "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL ANDREW TRICE OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "LowLatencyAudioAsset.h"

@implementation LowLatencyAudioAsset

-(id) initWithPath:(NSString*) path withVoices:(NSNumber*) numVoices withVolume:(NSNumber*) volume
{
    self = [super init];
    if(self) {
        
        NSURL *pathURL = [NSURL fileURLWithPath : path];
        
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:pathURL error: NULL];
        player.volume = volume.floatValue;
        _targetVolume = [volume floatValue];
        [player prepareToPlay];
        playIndex = 0;

        player.delegate = self;

    }
    return(self);
}

- (void) play
{
    [player setCurrentTime:0.0];
    _currentProgress = 0;
    player.numberOfLoops = 0;
    [player play];
    [self updateProgress];

}

- (void) updateProgress
{
    float progress = [player currentTime] / [player duration];
    if (progress >= _currentProgress && progress < 1.0) {
        _currentProgress = progress;
        if (self.onProgress) {
              self.onProgress(_currentProgress);
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self updateProgress];
        });
    }
}

- (void) stop
{
    [player stop];
}

- (void) loop
{
    [self stop];
    [player setCurrentTime:0.0];
    player.numberOfLoops = -1;
    [player play];
}

- (void) fadeIn:(NSNumber*) ms withIncrement:(NSNumber*) increment;
{
    [self stop];
    _ms = [ms integerValue];
    _increment = [increment floatValue];
    [player setCurrentTime:0.0];
    player.numberOfLoops = -1;
    player.volume = 0;
    [player play];
    [self doVolumeFadeIn];
}

-(void)doVolumeFadeIn {
    if (player.volume < _targetVolume) {
        player.volume += _increment;
        float delay = _increment * _ms * 0.001;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self doVolumeFadeIn];
        });
    }
}
- (void) fadeOut:(NSNumber*) ms withIncrement:(NSNumber*) increment;
{
    _ms = [ms integerValue];
    _increment = [increment floatValue];
    [self doVolumeFadeOut];
}

-(void)doVolumeFadeOut {
    if (player.volume > 0) {
        player.volume -= _increment;
        float delay = _increment * _ms * 0.001;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self doVolumeFadeOut];
        });
    } else {
        [player stop];
    }
}

- (void) unload
{
    [self stop];
    player = nil;
    
}

# pragma mark - AVAudioPlayerDelegate methods

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)audioPlayer successfully:(BOOL)flag {
    self.audioPlayerEventDidOccur(audioPlayer, flag);
}

- (void) audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)audioPlayer error:(NSError *)error {
    NSLog(@"audioPlayerDecodeErrorDidOccur: %@", error);
    self.audioPlayerEventDidOccur(audioPlayer, 0);
}

@end
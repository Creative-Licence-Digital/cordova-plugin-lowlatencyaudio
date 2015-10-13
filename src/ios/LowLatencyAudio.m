//
//  LowLatencyAudio.m
//  LowLatencyAudio
//
//  Created by Andrew Trice on 1/19/12.
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

#import "LowLatencyAudio.h"
#import <AVFoundation/AVAudioSession.h>

@implementation LowLatencyAudio

NSString* ERROR_NOT_FOUND = @"file not found";
NSString* WARN_EXISTING_REFERENCE = @"a reference to the audio ID already exists";
NSString* ERROR_MISSING_REFERENCE = @"a reference to the audio ID does not exist";
NSString* ERROR_AUDIO_DID_PLAY = @"audio did not play succesfully";
NSString* CONTENT_LOAD_REQUESTED = @"content has been requested";
NSString* PLAY_REQUESTED = @"PLAY REQUESTED";
NSString* PLAY_FINISHED = @"PLAY FINISHED";
NSString* STOP_REQUESTED = @"STOP REQUESTED";
NSString* UNLOAD_REQUESTED = @"UNLOAD REQUESTED";
NSString* RESTRICTED = @"ACTION RESTRICTED FOR FX AUDIO";

- (void)pluginInitialize
{
    // do some init work here.

    // set up audio so that user can play his own music
    // the audio is still silenced by screen locking and by the Silent switch
    AudioSessionInitialize(NULL, NULL, nil , nil);
    AVAudioSession *session = [AVAudioSession sharedInstance];

    NSError *setCategoryError = nil;
    if (![session setCategory:AVAudioSessionCategoryAmbient
                        error:&setCategoryError]) {
        // handle error
    }

    [session setActive: YES error: nil];
}

- (void) preloadFX:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];
    NSString *assetPath = [arguments objectAtIndex:1];

    NSLog( @"preloadFX - %@", assetPath );

    if(audioMapping == nil) {
        audioMapping = [NSMutableDictionary dictionary];
    }

    NSNumber* existingReference = [audioMapping objectForKey: audioID];
    if (existingReference == nil) {
        NSString* basePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"www"];
        NSString* path = [NSString stringWithFormat:@"%@", assetPath];
        NSString* pathFromWWW = [NSString stringWithFormat:@"%@/%@", basePath, assetPath];
        //NSLog(@"basePath: %@", basePath);
        //NSLog(@"path: %@", path);

        NSURL *pathURL;
        if ([assetPath hasPrefix:@"http://"] || [assetPath hasPrefix:@"https://"]) {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *path = paths.firstObject;
            path = [path stringByAppendingPathComponent:audioID];

            NSError *error;
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:assetPath]
                                                 options:NSDataReadingMappedIfSafe
                                                   error:&error];
            if (data && !error) {
                pathURL = [NSURL fileURLWithPath: path];
                [data writeToURL:pathURL options:NSDataWritingAtomic error:&error];
                if (error) {
                    NSLog(@"Error writing file to URL: %@", error);
                    pathURL = nil;
                }
            }
        }
        else
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath: path]) {
                pathURL = [NSURL fileURLWithPath: path];
            } else if ([[NSFileManager defaultManager] fileExistsAtPath: pathFromWWW]) {
                pathURL = [NSURL fileURLWithPath: pathFromWWW];
            }
        }

        if (pathURL) {
            CFURLRef soundFileURLRef = (CFURLRef) CFBridgingRetain(pathURL);
            SystemSoundID soundID;
            AudioServicesCreateSystemSoundID(soundFileURLRef, & soundID);
            [audioMapping setObject:[NSNumber numberWithInt:soundID] forKey: audioID];

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: CONTENT_LOAD_REQUESTED];

        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_NOT_FOUND];
        }

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: WARN_EXISTING_REFERENCE];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) preloadAudio:(CDVInvokedUrlCommand *)command
{
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];
    NSString *assetPath = [arguments objectAtIndex:1];

    NSLog( @"preloadAudio - %@", assetPath );

    NSNumber *volume = nil;
    if ( [arguments count] > 2 ) {
        volume = [arguments objectAtIndex:2];
        if([volume isEqual:nil]) {
            volume = [NSNumber numberWithFloat:1.0f];
        }
    } else {
        volume = [NSNumber numberWithFloat:1.0f];
    }

    NSLog( @"volume - %@", volume.stringValue );

    NSNumber *voices = nil;
    if ( [arguments count] > 3 ) {
        voices = [arguments objectAtIndex:3];
        if([voices isEqual:nil]) {
            voices = [NSNumber numberWithInt:1];
        }
    } else {
        voices = [NSNumber numberWithInt:1];
    }

    if(audioMapping == nil) {
        audioMapping = [NSMutableDictionary dictionary];
    }

    NSNumber* existingReference = [audioMapping objectForKey: audioID];

    [self.commandDelegate runInBackground:^{
        if (existingReference == nil) {
            NSString* path;

            if ([assetPath hasPrefix:@"http://"] || [assetPath hasPrefix:@"https://"]) {
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
                path = [paths.firstObject stringByAppendingPathComponent:audioID];

                NSError *error;
                NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:assetPath]
                                                     options:NSDataReadingMappedIfSafe
                                                       error:&error];
                if (data && !error) {
                    [data writeToURL:[NSURL fileURLWithPath: path] atomically:YES];
                }
            } else if ([assetPath hasPrefix:@"file://"]) {
              path = [assetPath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            } else {
              NSString* basePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"www"];
              path = [NSString stringWithFormat:@"%@/%@", basePath, assetPath];
            }

            if ([[NSFileManager defaultManager] fileExistsAtPath : path]) {
                LowLatencyAudioAsset* asset = [[LowLatencyAudioAsset alloc] initWithPath:path withVoices:voices withVolume:volume];
                [audioMapping setObject:asset  forKey: audioID];

                [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: CONTENT_LOAD_REQUESTED] callbackId:callbackId];
            } else {
                NSLog( @"audio file not found" );
                [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_NOT_FOUND] callbackId:callbackId];
            }
        } else {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: WARN_EXISTING_REFERENCE] callbackId:callbackId];
        }

    }];
}


- (void) play:(CDVInvokedUrlCommand *)command
{
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];

    //NSLog( @"play - %@", audioID );
    [self.commandDelegate runInBackground:^{
        if ( audioMapping ) {
            NSObject* asset = [audioMapping objectForKey: audioID];
            if ([asset isKindOfClass:[LowLatencyAudioAsset class]]) {
                LowLatencyAudioAsset *_asset = (LowLatencyAudioAsset*) asset;
                [_asset setAudioPlayerEventDidOccur:^(AVAudioPlayer *player, NSInteger status) {
                    if (status) {
                        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: PLAY_FINISHED] callbackId:callbackId];
                    } else {
                        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_AUDIO_DID_PLAY] callbackId:callbackId];
                    }
                }];
                [_asset play];
            } else if ( [asset isKindOfClass:[NSNumber class]] ) {
                NSNumber *_asset = (NSNumber*) asset;
                AudioServicesPlaySystemSound([_asset intValue]);
            }
        } else {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_MISSING_REFERENCE] callbackId:callbackId];
        }
    }];
}


- (void) fadeIn:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];
    NSNumber *ms = [arguments objectAtIndex:1];
    NSNumber *increment = [arguments objectAtIndex:2];


    NSLog( @"loop - %@", audioID );

    if ( audioMapping ) {
        NSObject* asset = [audioMapping objectForKey: audioID];
        if ([asset isKindOfClass:[LowLatencyAudioAsset class]]) {
            LowLatencyAudioAsset *_asset = (LowLatencyAudioAsset*) asset;
            [_asset fadeIn:ms withIncrement:increment];

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: STOP_REQUESTED];
        } else if ( [asset isKindOfClass:[NSNumber class]] ) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: RESTRICTED];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_MISSING_REFERENCE];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) fadeOut:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];
    NSNumber *ms = [arguments objectAtIndex:1];
    NSNumber *increment = [arguments objectAtIndex:2];


    //NSLog( @"stop - %@", audioID );

    if ( audioMapping ) {
        NSObject* asset = [audioMapping objectForKey: audioID];
        if ([asset isKindOfClass:[LowLatencyAudioAsset class]]) {
            LowLatencyAudioAsset *_asset = (LowLatencyAudioAsset*) asset;
            [_asset fadeOut:ms withIncrement:increment];

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: STOP_REQUESTED];
        } else if ( [asset isKindOfClass:[NSNumber class]] ) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: RESTRICTED];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_MISSING_REFERENCE];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}


- (void) stop:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];

    //NSLog( @"stop - %@", audioID );

    if ( audioMapping ) {
        NSObject* asset = [audioMapping objectForKey: audioID];
        if ([asset isKindOfClass:[LowLatencyAudioAsset class]]) {
            LowLatencyAudioAsset *_asset = (LowLatencyAudioAsset*) asset;
            [_asset stop];

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: STOP_REQUESTED];
        } else if ( [asset isKindOfClass:[NSNumber class]] ) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: RESTRICTED];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_MISSING_REFERENCE];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) loop:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];

    NSLog( @"loop - %@", audioID );

    if ( audioMapping ) {
        NSObject* asset = [audioMapping objectForKey: audioID];
        if ([asset isKindOfClass:[LowLatencyAudioAsset class]]) {
            LowLatencyAudioAsset *_asset = (LowLatencyAudioAsset*) asset;
            [_asset loop];

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: STOP_REQUESTED];
        } else if ( [asset isKindOfClass:[NSNumber class]] ) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: RESTRICTED];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_MISSING_REFERENCE];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void) unload:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult;
    NSString *callbackId = command.callbackId;
    NSArray* arguments = command.arguments;
    NSString *audioID = [arguments objectAtIndex:0];

    NSLog( @"unload - %@", audioID );

    if ( audioMapping ) {
        NSObject* asset = [audioMapping objectForKey: audioID];
        if ([asset isKindOfClass:[LowLatencyAudioAsset class]]) {
            LowLatencyAudioAsset *_asset = (LowLatencyAudioAsset*) asset;
            [_asset unload];
        } else if ( [asset isKindOfClass:[NSNumber class]] ) {
            NSNumber *_asset = (NSNumber*) asset;
            AudioServicesDisposeSystemSoundID([_asset intValue]);
        }

        [audioMapping removeObjectForKey: audioID];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString: UNLOAD_REQUESTED];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString: ERROR_MISSING_REFERENCE];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}


@end

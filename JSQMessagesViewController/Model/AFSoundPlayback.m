//
//  AFSoundPlayback.m
//  AFSoundManager-Demo
//
//  Created by Alvaro Franco on 21/01/15.
//  Copyright (c) 2015 AlvaroFranco. All rights reserved.
//

#import "AFSoundPlayback.h"
#import "AFSoundManager.h"
#import "NSTimer+AFSoundManager.h"

@interface AFSoundPlayback ()

-(void)setUpItem:(AFSoundItem *)item;

@property (nonatomic, strong) NSTimer *feedbackTimer;

@end

@implementation AFSoundPlayback

NSString * const AFSoundPlaybackStatus = @"status";
NSString * const AFSoundStatusDuration = @"duration";
NSString * const AFSoundStatusTimeElapsed = @"timeElapsed";

NSString * const AFSoundPlaybackFinishedNotification = @"kAFSoundPlaybackFinishedNotification";

-(id)initWithItem:(AFSoundItem *)item {
    
    if (self == [super init]) {
        
        _currentItem = item;
        [self setUpItem:item];
        
        _status = AFSoundStatusNotStarted;
    }
    
    return self;
}

-(void)setUpItem:(AFSoundItem *)item {
    
    _player = [[AVPlayer alloc] initWithURL:item.URL];
    [_player play];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    
    _status = AFSoundStatusPlaying;

    _currentItem = item;
    _currentItem.duration = (int)CMTimeGetSeconds(_player.currentItem.asset.duration);
        
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

-(void)listenFeedbackUpdatesWithBlock:(feedbackBlock)block andFinishedBlock:(finishedBlock)finishedBlock {
    
    CGFloat updateRate = 1;
    
    if (_player.rate > 0) {
        
        updateRate = 1 / _player.rate;
    }
    
    _feedbackTimer = [NSTimer scheduledTimerWithTimeInterval:updateRate block:^{
        
        _currentItem.timePlayed = (int)CMTimeGetSeconds(_player.currentTime);
        
        if (block) {

            block(_currentItem);
        }
        
        if (self.statusDictionary[AFSoundStatusDuration] == self.statusDictionary[AFSoundStatusTimeElapsed]) {
            
            [_feedbackTimer pauseTimer];
            
            _status = AFSoundStatusFinished;
            
            if (finishedBlock) {
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    finishedBlock();
                });
            }
        }
    } repeats:YES];
}

-(NSDictionary *)playingInfo {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setValue:[NSNumber numberWithDouble:CMTimeGetSeconds(_player.currentItem.currentTime)] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [dict setValue:@(_player.rate) forKey:MPNowPlayingInfoPropertyPlaybackRate];
    
    return dict;
}

-(void)play {
    
    [_player play];
    [_feedbackTimer resumeTimer];
    [[MPRemoteCommandCenter sharedCommandCenter] playCommand];
    
    _status = AFSoundStatusPlaying;
}

-(void)pause {
    
    [_player pause];
    [_feedbackTimer pauseTimer];
    [[MPRemoteCommandCenter sharedCommandCenter] pauseCommand];
    
    _status = AFSoundStatusPaused;
}

-(void)restart {
    
    [_player seekToTime:CMTimeMake(0, 1)];
     _status = AFSoundStatusNotStarted;
}

-(void)playAtSecond:(NSInteger)second {
    _status = AFSoundStatusPlaying;
    [_player seekToTime:CMTimeMake(second, 1)];
    
}

-(void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
                
            case UIEventSubtypeRemoteControlTogglePlayPause:
                [self play];
                break;
                
            default:
                break;
        }
    }
}

-(NSDictionary *)statusDictionary {
    
    return @{AFSoundStatusDuration: @((int)CMTimeGetSeconds(_player.currentItem.asset.duration)),
             AFSoundStatusTimeElapsed: @((int)CMTimeGetSeconds(_player.currentItem.currentTime)),
             AFSoundPlaybackStatus: @(_status)};
}

@end

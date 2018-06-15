//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQAudioMediaItem.h"

#import "JSQMessagesMediaPlaceholderView.h"
#import "JSQMessagesMediaViewBubbleImageMasker.h"

#import "UIImage+JSQMessages.h"
#import "UIColor+JSQMessages.h"



@interface JSQAudioMediaItem ()

@property (strong, nonatomic) UIView *cachedMediaView;
@property (strong, nonatomic) NSTimer *progressTimer;
@property (nonatomic, strong) AFSoundQueue *queue;
@property (nonatomic, strong) NSMutableArray *items;
@end


@implementation JSQAudioMediaItem

#pragma mark - Initialization

- (instancetype)initWithData:(NSData *)audioData audioViewAttributes:(JSQAudioMediaViewAttributes *)audioViewAttributes
{
    NSParameterAssert(audioViewAttributes != nil);

    self = [super init];
    if (self) {
        _cachedMediaView = nil;
        _audioData = [audioData copy];
        _audioViewAttributes = audioViewAttributes;

    }
    return self;
}

- (instancetype)initWithData:(NSData *)audioData
{
    return [self initWithData:audioData audioViewAttributes:[[JSQAudioMediaViewAttributes alloc] init]];
}

- (instancetype)initWithAudioViewAttributes:(JSQAudioMediaViewAttributes *)audioViewAttributes
{
    return [self initWithData:nil audioViewAttributes:audioViewAttributes];
}

- (instancetype)init
{
    return [self initWithData:nil audioViewAttributes:[[JSQAudioMediaViewAttributes alloc] init]];
}

- (void)dealloc
{
    _audioData = nil;
    [self clearCachedMediaViews];
}

- (void)clearCachedMediaViews
{
    [_audioPlayer stop];
    _audioPlayer = nil;

    _playButton = nil;
    _progressView = nil;
    _progressLabel = nil;
    [self stopProgressTimer];

    _cachedMediaView = nil;
    [super clearCachedMediaViews];
}

#pragma mark - Setters

- (void)setAudioData:(NSData *)audioData
{
    _audioData = [audioData copy];
    [self clearCachedMediaViews];
}

- (void)setAudioDataWithUrl:(NSURL *)audioURL
{
    self.urlAudio = audioURL;
    [self clearCachedMediaViews];
}

- (void)setAppliesMediaViewMaskAsOutgoing:(BOOL)appliesMediaViewMaskAsOutgoing
{
    [super setAppliesMediaViewMaskAsOutgoing:appliesMediaViewMaskAsOutgoing];
    _cachedMediaView = nil;
}

#pragma mark - Private

- (void)startProgressTimer
{
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                          target:self
                                                        selector:@selector(updateProgressTimer:)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)stopProgressTimer
{
    [_progressTimer invalidate];
    _progressTimer = nil;
}

- (void)updateProgressTimer:(NSTimer *)sender
{
    if (self.audioPlayer.playing) {
        self.progressView.progress = self.audioPlayer.currentTime / self.audioPlayer.duration;
        self.progressLabel.text = [self timestampString:self.audioPlayer.currentTime
                                            forDuration:self.audioPlayer.duration];
    }
}
- (void)updateProgess:(NSTimeInterval)currentTime forDuration:(NSTimeInterval)duration{
    self.playButton.selected = YES;
    float interval = (float)currentTime/ (float)duration;
    self.currentPlayer = currentTime;
    self.progressView.progress = interval;
    self.progressLabel.text = [self timestampString:duration - currentTime forDuration:duration];
}

- (void)resetProgess{
    self.playButton.selected = NO;
    self.progressView.progress = 0;
    self.progressLabel.text = [self timestampString:self.durationPlayer forDuration:self.durationPlayer];
    self.currentPlayer = 0;
}

- (NSString *)timestampString:(NSTimeInterval)currentTime forDuration:(NSTimeInterval)duration
{
    // print the time as 0:ss or ss.x up to 59 seconds
    // print the time as m:ss up to 59:59 seconds
    // print the time as h:mm:ss for anything longer
    if (duration < 60) {
        if (self.audioViewAttributes.showFractionalSeconds) {
            return [NSString stringWithFormat:@"%.01f", currentTime];
        }
        else if (currentTime < duration) {
            return [NSString stringWithFormat:@"0:%02d", (int)round(currentTime)];
        }
        return [NSString stringWithFormat:@"0:%02d", (int)ceil(currentTime)];
    }
    else if (duration < 3600) {
        return [NSString stringWithFormat:@"%d:%02d", (int)currentTime / 60, (int)currentTime % 60];
    }

    return [NSString stringWithFormat:@"%d:%02d:%02d", (int)currentTime / 3600, (int)currentTime / 60, (int)currentTime % 60];
}

- (void)onStreamAudioButton:(UIButton *)sender {
    [self.playButton setUserInteractionEnabled:NO];
    [self clickPlayButton];
    [self.playButton setUserInteractionEnabled:YES];
}

- (void)clickPlayButton{
    
    if( self.playButton.selected){
        self.playButton.selected = NO;
        [self.delegate pauseAudio:self];
    }else{
        self.playButton.selected = YES;
        [self.delegate playAudio:self];
    }
}
- (void)resetPlayer{
    self.playButton.selected = NO;
    self.progressView.progress = 0;
    self.progressLabel.text = [self timestampString:0 forDuration:0];
    self.currentPlayer = 0;
    [_player pause];
    [_player restart];
}


- (BOOL)isLocalFile:(NSURL*)url{
    if ([[url scheme] isEqualToString:@"file"]) {
        return true;
    }
    return false;
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag {

    // set progress to full, then fade back to the default state
    [self stopProgressTimer];
    self.progressView.progress = 1;
    [UIView transitionWithView:self.cachedMediaView
                      duration:.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.progressView.progress = 0;
                        self.playButton.selected = NO;
                        self.progressLabel.text = [self timestampString:self.audioPlayer.duration
                                                            forDuration:self.audioPlayer.duration];
                    }
                    completion:nil];
}

#pragma mark - JSQMessageMediaData protocol

- (CGSize)mediaViewDisplaySize
{
    return CGSizeMake(210.0f,
                      self.audioViewAttributes.controlInsets.top +
                      self.audioViewAttributes.controlInsets.bottom +
                      self.audioViewAttributes.playButtonImage.size.height);
}

- (UIView *)mediaView
{
    return self.cachedMediaView;
}

- (UIView *)mediaViewPlacholder{
    
    // reverse the insets based on the message direction
    _currentPlayer = 0;
    CGFloat leftInset, rightInset;
    if (self.appliesMediaViewMaskAsOutgoing) {
        leftInset = self.audioViewAttributes.controlInsets.left;
        rightInset = self.audioViewAttributes.controlInsets.right;
    } else {
        leftInset = self.audioViewAttributes.controlInsets.right;
        rightInset = self.audioViewAttributes.controlInsets.left;
    }
    
    // create container view for the various controls
    CGSize size = [self mediaViewDisplaySize];
    UIView * playView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    playView.backgroundColor = self.audioViewAttributes.backgroundColor;
    playView.contentMode = UIViewContentModeCenter;
    playView.clipsToBounds = YES;
    
    // create the play button
    CGRect buttonFrame = CGRectMake(leftInset - 4,self.audioViewAttributes.controlInsets.top - 4,
                                    self.audioViewAttributes.playButtonImage.size.width + 8,
                                    self.audioViewAttributes.playButtonImage.size.height + 8);
    
    self.playButton = [[UIButton alloc] initWithFrame:buttonFrame];
    self.playButton.imageEdgeInsets = UIEdgeInsetsMake(4, 8, 4, 0);
    [self.playButton setImage:self.audioViewAttributes.playButtonImage forState:UIControlStateNormal];
    [self.playButton setImage:self.audioViewAttributes.pauseButtonImage forState:UIControlStateSelected];
    [self.playButton addTarget:self action:@selector(onStreamAudioButton:) forControlEvents:UIControlEventTouchUpInside];
    [playView addSubview:self.playButton];
    
    // create a label to show the duration / elapsed time
    NSString *durationString = [self timestampString:self.durationPlayer
                                         forDuration:self.durationPlayer];
    NSString *maxWidthString = [@"" stringByPaddingToLength:[durationString length] withString:@"0" startingAtIndex:0];
    
    // this is cheesy, but it centers the progress bar without extra space and
    // without causing it to wiggle from side to side as the label text changes
    CGSize labelSize = CGSizeMake(40, 18);
    if ([durationString length] < 4) {
        labelSize = CGSizeMake(20,18);
    }
    else if ([durationString length] < 5) {
        labelSize = CGSizeMake(26,18);
    }
    else if ([durationString length] < 6) {
        labelSize = CGSizeMake(32, 18);
    }
    
    CGRect labelFrame = CGRectMake(size.width - labelSize.width - rightInset - 4,self.audioViewAttributes.controlInsets.top, labelSize.width, labelSize.height);
    self.progressLabel = [[UILabel alloc] initWithFrame:labelFrame];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    self.progressLabel.adjustsFontSizeToFitWidth = YES;
    self.progressLabel.textColor = [UIColor whiteColor];
    self.progressLabel.font = self.audioViewAttributes.labelFont;
    self.progressLabel.text = maxWidthString;
    self.progressLabel.backgroundColor = self.audioViewAttributes.tintColor;
    self.progressLabel.clipsToBounds = true;
    self.progressLabel.layer.cornerRadius = 6;
    
    // sizeToFit adjusts the frame's height to the font
    [self.progressLabel sizeToFit];
    labelFrame.origin.x = size.width - self.progressLabel.frame.size.width - rightInset - 4 ;
    labelFrame.origin.y =  ((size.height - self.progressLabel.frame.size.height) / 2);
    labelFrame.size.width = self.progressLabel.frame.size.width;
    labelFrame.size.height =  self.progressLabel.frame.size.height;
    self.progressLabel.frame = labelFrame;
    self.progressLabel.text = durationString;
    [playView addSubview:self.progressLabel];
    
    // create a progress bar
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [self.progressView setTransform:CGAffineTransformMakeScale(1.0, 1.0)];
    CGFloat xOffset = self.playButton.frame.origin.x + self.playButton.frame.size.width + self.audioViewAttributes.controlPadding - 3;
    self.progressView.trackTintColor = [UIColor colorWithRed:0.9882352941 green:0.646905992 blue:0.9740496174 alpha:1.0];
    CGFloat width = labelFrame.origin.x - xOffset;
    self.progressView.frame = CGRectMake(xOffset, (size.height - self.progressView.frame.size.height) / 2,width, self.progressView.frame.size.height);
    self.progressView.tintColor = self.audioViewAttributes.tintColor;
    [playView addSubview:self.progressView];
    
    [JSQMessagesMediaViewBubbleImageMasker applyBubbleImageMaskToMediaView:playView isOutgoing:self.appliesMediaViewMaskAsOutgoing];
    self.cachedMediaView = playView;
    return playView;
}

- (NSUInteger)mediaHash
{
    return self.hash;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (![super isEqual:object]) {
        return NO;
    }

    JSQAudioMediaItem *audioItem = (JSQAudioMediaItem *)object;
    if (self.audioData && ![self.audioData isEqualToData:audioItem.audioData]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    return super.hash ^ self.audioData.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: audioData=%ld bytes, appliesMediaViewMaskAsOutgoing=%@>",
            [self class], (unsigned long)[self.audioData length],
            @(self.appliesMediaViewMaskAsOutgoing)];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    NSData *data = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(audioData))];
    return [self initWithData:data];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.audioData forKey:NSStringFromSelector(@selector(audioData))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone
{
    JSQAudioMediaItem *copy = [[[self class] allocWithZone:zone] initWithData:self.audioData
                                                          audioViewAttributes:self.audioViewAttributes];
    copy.appliesMediaViewMaskAsOutgoing = self.appliesMediaViewMaskAsOutgoing;
    return copy;
}

@end

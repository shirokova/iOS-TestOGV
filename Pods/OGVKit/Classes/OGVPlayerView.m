//
//  OGVPlayerView.m
//  OGVKit
//
//  Created by Brion on 2/8/15.
//  Copyright (c) 2015 Brion Vibber. All rights reserved.
//

#import "OGVKit.h"

@import CoreText;

static NSString *kOGVPlayerTimeLabelEmpty = @"-:--";

// Icons from Font Awesome custom subset
static NSString *kOGVPlayerIconCharPlay = @"\ue800";
static NSString *kOGVPlayerIconCharStop = @"\ue801";
static NSString *kOGVPlayerIconCharPause = @"\ue802";
static NSString *kOGVPlayerIconCharToEnd = @"\ue803";
static NSString *kOGVPlayerIconCharToEndAlt = @"\ue804";
static NSString *kOGVPlayerIconCharToStart = @"\ue805";
static NSString *kOGVPlayerIconCharToStartAlt = @"\ue806";
static NSString *kOGVPlayerIconCharFastFw = @"\ue807";
static NSString *kOGVPlayerIconCharFastBw = @"\ue808";
static NSString *kOGVPlayerIconCharEject = @"\ue809";
static NSString *kOGVPlayerIconCharPlayCircled = @"\ue80a";
static NSString *kOGVPlayerIconCharPlayCircled2 = @"\ue80b";
static NSString *kOGVPlayerIconCharResizeFull = @"\ue80c";
static NSString *kOGVPlayerIconCharResizeSmall = @"\ue80d";
static NSString *kOGVPlayerIconCharVolumeOff = @"\ue810";
static NSString *kOGVPlayerIconCharVolumeDown = @"\ue811";
static NSString *kOGVPlayerIconCharVolumeUp = @"\ue812";
static NSString *kOGVPlayerIconCharCog = @"\ue814";
static NSString *kOGVPlayerIconCharExport = @"\ue817";
static NSString *kOGVPlayerIconCharResizeVertical = @"\ue818";

static BOOL OGVPlayerViewDidRegisterIconFont = NO;

@implementation OGVPlayerView

{
    NSURL *_sourceURL;
    OGVPlayerState *state;
    NSTimer *timeTimer;
    NSTimer *controlsTimeout;
    NSTimer *seekTimeout;
    BOOL seeking;
}

#pragma mark - Public methods

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setup];
    }
    return self;
}

- (NSURL *)sourceURL
{
    return _sourceURL;
}

- (void)setSourceURL:(NSURL *)sourceURL
{
    if (state) {
        [state cancel];
        [self.frameView clearFrame];
        state = nil;
    }
    _sourceURL = [sourceURL copy];
    [self updateTimeLabel];
    if (_sourceURL) {
        state = [[OGVPlayerState alloc] initWithURL:_sourceURL delegate:self];
    }
}

-(void)play
{
    [state play];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    if (state) {
        [state cancel];
    }
}

-(BOOL)paused
{
    if (state) {
        return state.paused;
    } else {
        return NO;
    }
}

-(void)pause
{
    if (state) {
        [state pause];
    }
}

- (void)seek:(float)seconds
{
    if (state) {
        [state seek:seconds];
    }
}

- (float)playbackPosition
{
    if (state) {
        return state.playbackPosition;
    } else {
        return 0;
    }
}

#pragma mark - private methods

-(void)setup
{
    NSBundle *bundle = [[OGVKit singleton]
                        resourceBundle];

    if (!OGVPlayerViewDidRegisterIconFont) {
        NSURL *fontURL = [bundle URLForResource:@"ogvkit-iconfont" withExtension:@"ttf"];
        CTFontManagerRegisterFontsForURL((__bridge CFURLRef)fontURL, kCTFontManagerScopeProcess, nil);
        OGVPlayerViewDidRegisterIconFont = YES;
    }

    UINib *nib = [UINib nibWithNibName:@"OGVPlayerView" bundle:bundle];
    UIView *interface = [nib instantiateWithOwner:self options:nil][0];

    // @todo move this into OGVFrameView
    self.frameView.context = [self createGLContext];

    // can this be set in the nib?
    [self.pausePlayButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];

    // ok load that nib into our view \o/
    interface.frame = self.bounds;
    interface.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:interface];

    NSDictionary *layoutViews = NSDictionaryOfVariableBindings(interface);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[interface]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:layoutViews]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[interface]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:layoutViews]];

    // Events
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(onViewTapped:)];
    [self addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

-(EAGLContext *)createGLContext
{
    EAGLContext *context;
    if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_7_0) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    }
    if (context == nil) {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    return context;
}

- (IBAction)togglePausePlay:(id)sender
{
    if (state) {
        if (state.paused) {
            [state play];
        } else {
            [state pause];
        }
    }
}

-(void)onViewTapped:(id)obj
{
    if (state && !state.paused) {
        if ([self controlsAreHidden]) {
            [self showControls];
        } else if ([self controlsAreVisible]) {
            [self hideControls];
        } else {
            // controls are in transition; don't mess with them.
        }
    }
}

- (IBAction)onProgressSliderChanged:(id)sender {
    if (state.seekable) {
        seeking = YES;
        if (seekTimeout) {
            [seekTimeout invalidate];
        }
        seekTimeout = [NSTimer timerWithTimeInterval:0.25f target:self selector:@selector(onSeekTimeout:) userInfo:state repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:seekTimeout forMode:NSRunLoopCommonModes];

        [self updateTimeLabel];
    }
}

- (IBAction)onProgressSliderReleased:(id)sender {
    if (seeking) {
        if (seekTimeout) {
            [seekTimeout invalidate];
            seekTimeout = nil;

            float targetTime = self.progressSlider.value * state.duration;
            [state seek:targetTime];
            [self.activityIndicator startAnimating];
            self.activityIndicator.hidden = NO;
            // we'll pick this up in ogvPlayerStateDidSeek
        }
    }
}

-(void)onSeekTimeout:(NSTimer *)timer
{
    if (timer.userInfo == state) {
        float targetTime = self.progressSlider.value * state.duration;
        [state seek:targetTime];

        seekTimeout = nil;
    }
}

-(BOOL)controlsAreVisible
{
    return (self.controlBar.alpha == 1.0f);
}

-(BOOL)controlsAreHidden
{
    return (self.controlBar.alpha == 0.0f);
}

-(void)hideControls
{
     if ([self.delegate respondsToSelector:@selector(ogvPlayerControlsWillHide:)]) {
        [self.delegate ogvPlayerControlsWillHide:self];
    }

    [UIView animateWithDuration:0.5f animations:^{
        self.controlBar.alpha = 0.0001f;
    } completion:^(BOOL finished) {
        self.controlBar.alpha = 0.0f;
    }];
}

-(void)showControls
{
    if ([self.delegate respondsToSelector:@selector(ogvPlayerControlsWillShow:)]) {
        [self.delegate ogvPlayerControlsWillShow:self];
    }

    if (self.controlBar.alpha == 0.0f) {
        self.controlBar.alpha = 0.0001f;
    }
    [UIView animateWithDuration:0.5f animations:^{
        self.controlBar.alpha = 1.0f;
    }];
}

-(void)stopControlsTimeout
{
    if (controlsTimeout) {
        [controlsTimeout invalidate];
        controlsTimeout = nil;
    }
}

-(void)startControlsTimeout
{
    if (controlsTimeout) {
        [self stopControlsTimeout];
    }
    if (!controlsTimeout) {
        controlsTimeout = [NSTimer scheduledTimerWithTimeInterval:4.0f
                                                           target:self
                                                         selector:@selector(pingControlsTimeout:)
                                                         userInfo:nil
                                                          repeats:NO];
    }
}

-(void)pingControlsTimeout:(NSTimer *)timer
{
    if ([self controlsAreVisible]) {
        [self hideControls];
    }
}

-(void)appDidEnterBackground:(id)obj
{
    [self pause];
}

-(void)stopTimeTimer
{
    if (timeTimer) {
        [timeTimer invalidate];
        timeTimer = nil;
    }
}

-(void)startTimeTimer
{
    if (!timeTimer) {
        timeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                     target:self
                                                   selector:@selector(pingTimeTimer:)
                                                   userInfo:nil
                                                    repeats:YES];
    }
}

-(void)pingTimeTimer:(NSTimer *)timer
{
    [self updateTimeLabel];
}

-(void)updateTimeLabel
{
    if (state) {
        float duration = state.duration;
        float position;
        if (seeking) {
            position = self.progressSlider.value * duration;
        } else {
            position = state.playbackPosition;
            self.progressSlider.value = position / duration;
        }
        self.timeLabel.text = [self formatTime:position];

        if (duration < INFINITY) {
            self.timeRemainingLabel.text = [self formatTime:position - duration];
            self.progressSlider.enabled = state.seekable;
            self.progressSlider.hidden = NO;
        } else {
            self.timeRemainingLabel.text = @"";
            self.progressSlider.value = 0;
            self.progressSlider.hidden = YES;
        }
    } else {
        self.timeLabel.text = kOGVPlayerTimeLabelEmpty;
        self.timeRemainingLabel.text = @"";
        self.progressSlider.value = 0;
        self.progressSlider.hidden = YES;
    }
}

-(NSString *)formatTime:(float)seconds
{
    int rounded = (int)roundf(seconds);
    int min = rounded / 60;
    int sec = abs(rounded % 60);
    return [NSString stringWithFormat:@"%d:%02d", min, sec];
}

#pragma mark - OGVPlayerStateDelegate methods

- (void)ogvPlayerState:(OGVPlayerState *)sender drawFrame:(OGVVideoBuffer *)buffer
{
    if (sender == state) {
        [self.frameView drawFrame:buffer];
    }
}

- (void)ogvPlayerStateDidLoadMetadata:(OGVPlayerState *)sender
{
    if (sender == state) {
        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidLoadMetadata:)]) {
            [self.delegate ogvPlayerDidLoadMetadata:self];
        }
    }
}

- (void)ogvPlayerStateDidPlay:(OGVPlayerState *)sender
{
    if (sender == state) {
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPause forState:UIControlStateNormal];
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPause forState:UIControlStateHighlighted];
        [self startTimeTimer];
        [self updateTimeLabel];

        if (![self controlsAreVisible]) {
            [self showControls];
        }
        [self startControlsTimeout];

        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidPlay:)]) {
            [self.delegate ogvPlayerDidPlay:self];
        }
    }
}

- (void)ogvPlayerStateDidPause:(OGVPlayerState *)sender
{
    if (sender == state) {
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPlay forState:UIControlStateNormal];
        [self.pausePlayButton setTitle:kOGVPlayerIconCharPlay forState:UIControlStateHighlighted];
        [self updateTimeLabel];
        [self stopTimeTimer];

        if ([self controlsAreHidden]) {
            [self showControls];
        } else {
            [self stopControlsTimeout];
        }

        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidPause:)]) {
            [self.delegate ogvPlayerDidPause:self];
        }
    }
}

- (void)ogvPlayerStateDidEnd:(OGVPlayerState *)sender
{
    if (sender == state) {
        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidEnd:)]) {
            [self.delegate ogvPlayerDidEnd:self];
        }
    }
}

- (void)ogvPlayerStateDidSeek:(OGVPlayerState *)sender
{
    if (sender == state) {
        seeking = NO;
        self.activityIndicator.hidden = YES;
        [self.activityIndicator stopAnimating];
        [self updateTimeLabel];

        if ([self.delegate respondsToSelector:@selector(ogvPlayerDidSeek:)]) {
            [self.delegate ogvPlayerDidSeek:self];
        }
    }
}

@end

#import <Capacitor/Capacitor.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

CAP_PLUGIN(NativeAudioPlugin, "NativeAudio",
    CAP_PLUGIN_METHOD(initEngine, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(playNote, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(playMetro, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(releaseAllNotes, CAPPluginReturnPromise);
)

@implementation NativeAudioPlugin {
    NSMutableDictionary<NSNumber *, NSData *> *_sampleDataMap;
    NSMutableDictionary<NSNumber *, NSMutableArray *> *_samplePlayers;
    NSMutableDictionary<NSString *, id> *_metroPlayers;
    BOOL _isEngineSetup;
}

- (void)pluginInitialize {
    _sampleDataMap = [NSMutableDictionary new];
    _samplePlayers = [NSMutableDictionary new];
    _metroPlayers = [NSMutableDictionary new];
    _isEngineSetup = NO;
}

- (NSURL *)findAudioUrlForFile:(NSString *)fileName subDir:(NSString *)subDir {
    NSArray *extensions = @[@"mp3", @"m4a"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *bundleUrl = [[NSBundle mainBundle] bundleURL];
    NSString *shortSub = [subDir stringByReplacingOccurrencesOfString:@"public/" withString:@""];
    
    for (NSString *ext in extensions) {
        NSURL *url1 = [[NSBundle mainBundle] URLForResource:fileName withExtension:ext subdirectory:subDir];
        if (url1) return url1;
        
        NSURL *url2 = [[NSBundle mainBundle] URLForResource:fileName withExtension:ext subdirectory:shortSub];
        if (url2) return url2;
        
        NSURL *url3 = [[NSBundle mainBundle] URLForResource:fileName withExtension:ext];
        if (url3) return url3;
        
        NSURL *url4 = [bundleUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@.%@", subDir, fileName, ext]];
        if ([fm fileExistsAtPath:[url4 path]]) return url4;
        
        NSURL *url5 = [bundleUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@.%@", shortSub, fileName, ext]];
        if ([fm fileExistsAtPath:[url5 path]]) return url5;
    }
    return nil;
}

- (void)setupEngineInternal {
    if (_isEngineSetup) return;
    
    // Carga dinámica del framework AVFoundation para evitar vincular headers desalineados
    dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation", RTLD_NOW);
    
    // Configurar AVAudioSession mediante introspección
    Class audioSessionClass = NSClassFromString(@"AVAudioSession");
    if (audioSessionClass) {
        SEL sharedSessionSel = NSSelectorFromString(@"sharedInstance");
        if ([audioSessionClass respondsToSelector:sharedSessionSel]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id session = [audioSessionClass performSelector:sharedSessionSel];
            #pragma clang diagnostic pop
            
            if (session) {
                SEL setCategorySel = NSSelectorFromString(@"setCategory:error:");
                if ([session respondsToSelector:setCategorySel]) {
                    typedef BOOL (*SetCategoryFn)(id, SEL, NSString *, NSError **);
                    SetCategoryFn fn = (SetCategoryFn)[session methodForSelector:setCategorySel];
                    fn(session, setCategorySel, @"AVAudioSessionCategoryPlayback", nil);
                }
                SEL setActiveSel = NSSelectorFromString(@"setActive:error:");
                if ([session respondsToSelector:setActiveSel]) {
                    typedef BOOL (*SetActiveFn)(id, SEL, BOOL, NSError **);
                    SetActiveFn fn = (SetActiveFn)[session methodForSelector:setActiveSel];
                    fn(session, setActiveSel, YES, nil);
                }
            }
        }
    }
    
    NSDictionary<NSNumber *, NSString *> *noteMap = @{
        @21: @"A0", @24: @"C1", @27: @"Ds1", @30: @"Fs1",
        @33: @"A1", @36: @"C2", @39: @"Ds2", @42: @"Fs2",
        @45: @"A2", @48: @"C3", @51: @"Ds3", @54: @"Fs3",
        @57: @"A3", @60: @"C4", @63: @"Ds4", @66: @"Fs4",
        @69: @"A4", @72: @"C5", @75: @"Ds5", @78: @"Fs5",
        @81: @"A5", @84: @"C6", @87: @"Ds6", @90: @"Fs6",
        @93: @"A6", @96: @"C7", @99: @"Ds7", @102: @"Fs7", @108: @"C8"
    };
    
    Class playerClass = NSClassFromString(@"AVAudioPlayer");
    SEL initURLSel = NSSelectorFromString(@"initWithContentsOfURL:error:");
    
    // Cargar Muestras de Piano
    for (NSNumber *note in noteMap) {
        NSString *fileName = noteMap[note];
        NSURL *soundUrl = [self findAudioUrlForFile:fileName subDir:@"public/audio/piano"];
        if (soundUrl) {
            NSData *data = [NSData dataWithContentsOfURL:soundUrl];
            if (data) {
                _sampleDataMap[note] = data;
            }
        }
    }
    
    // Cargar Metrónomo
    for (NSString *metroType in @[@"wood-hi", @"wood-lo"]) {
        NSURL *soundUrl = [self findAudioUrlForFile:metroType subDir:@"public/audio/metro"];
        if (soundUrl && playerClass && [playerClass instancesRespondToSelector:initURLSel]) {
            NSError *err = nil;
            typedef id (*InitWithURLFn)(id, SEL, NSURL *, NSError **);
            InitWithURLFn fnURL = (InitWithURLFn)[playerClass instanceMethodForSelector:initURLSel];
            id player = fnURL([playerClass alloc], initURLSel, soundUrl, &err);
            if (player) {
                SEL prepSel = NSSelectorFromString(@"prepareToPlay");
                if ([player respondsToSelector:prepSel]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [player performSelector:prepSel];
                    #pragma clang diagnostic pop
                }
                _metroPlayers[metroType] = player;
            }
        }
    }
    
    _isEngineSetup = YES;
    NSLog(@"🎹 [NativeAudio] ObjC Dynamic Audio Engine iniciado con éxito. Muestras Piano: %lu, Metrónomo: %lu",
          (unsigned long)_sampleDataMap.count, (unsigned long)_metroPlayers.count);
}

- (void)initEngine:(CAPPluginCall *)call {
    [self setupEngineInternal];
    [call resolve:@{@"status": @"initialized"}];
}

- (void)playNote:(CAPPluginCall *)call {
    if (!_isEngineSetup) [self setupEngineInternal];
    
    NSDictionary *options = call.options;
    NSInteger midiNote = options[@"note"] ? [options[@"note"] integerValue] : 60;
    float velocity = options[@"velocity"] ? [options[@"velocity"] floatValue] / 127.0f : 100.0f / 127.0f;
    
    NSNumber *targetNote = @(midiNote);
    if (!_sampleDataMap[targetNote]) {
        NSArray *keys = [_sampleDataMap.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSInteger minDiff = 999;
        for (NSNumber *key in keys) {
            NSInteger diff = labs(key.integerValue - midiNote);
            if (diff < minDiff) {
                minDiff = diff;
                targetNote = key;
            }
        }
    }
    
    NSData *data = _sampleDataMap[targetNote];
    if (!data) {
        [call resolve];
        return;
    }
    
    Class playerClass = NSClassFromString(@"AVAudioPlayer");
    if (!playerClass) {
        [call resolve];
        return;
    }
    
    NSMutableArray *pool = _samplePlayers[targetNote];
    if (!pool) {
        pool = [NSMutableArray new];
        _samplePlayers[targetNote] = pool;
    }
    
    id availablePlayer = nil;
    SEL isPlayingSel = NSSelectorFromString(@"isPlaying");
    for (id p in pool) {
        typedef BOOL (*IsPlayingFn)(id, SEL);
        IsPlayingFn fn = (IsPlayingFn)[p methodForSelector:isPlayingSel];
        if (!fn(p, isPlayingSel)) {
            availablePlayer = p;
            break;
        }
    }
    
    if (availablePlayer) {
        SEL setTimeSel = NSSelectorFromString(@"setCurrentTime:");
        if ([availablePlayer respondsToSelector:setTimeSel]) {
            typedef void (*SetTimeFn)(id, SEL, NSTimeInterval);
            SetTimeFn fn = (SetTimeFn)[availablePlayer methodForSelector:setTimeSel];
            fn(availablePlayer, setTimeSel, 0.0);
        }
        SEL setVolSel = NSSelectorFromString(@"setVolume:");
        if ([availablePlayer respondsToSelector:setVolSel]) {
            typedef void (*SetVolFn)(id, SEL, float);
            SetVolFn fn = (SetVolFn)[availablePlayer methodForSelector:setVolSel];
            fn(availablePlayer, setVolSel, velocity);
        }
        SEL playSel = NSSelectorFromString(@"play");
        if ([availablePlayer respondsToSelector:playSel]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [availablePlayer performSelector:playSel];
            #pragma clang diagnostic pop
        }
    } else {
        SEL initDataSel = NSSelectorFromString(@"initWithData:error:");
        if ([playerClass instancesRespondToSelector:initDataSel]) {
            NSError *err = nil;
            typedef id (*InitDataFn)(id, SEL, NSData *, NSError **);
            InitDataFn initFn = (InitDataFn)[playerClass instanceMethodForSelector:initDataSel];
            id newPlayer = initFn([playerClass alloc], initDataSel, data, &err);
            if (newPlayer) {
                SEL setVolSel = NSSelectorFromString(@"setVolume:");
                if ([newPlayer respondsToSelector:setVolSel]) {
                    typedef void (*SetVolFn)(id, SEL, float);
                    SetVolFn fn = (SetVolFn)[newPlayer methodForSelector:setVolSel];
                    fn(newPlayer, setVolSel, velocity);
                }
                SEL playSel = NSSelectorFromString(@"play");
                if ([newPlayer respondsToSelector:playSel]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [newPlayer performSelector:playSel];
                    #pragma clang diagnostic pop
                }
                if (pool.count < 4) {
                    [pool addObject:newPlayer];
                }
            }
        }
    }
    
    [call resolve];
}

- (void)playMetro:(CAPPluginCall *)call {
    if (!_isEngineSetup) [self setupEngineInternal];
    
    NSDictionary *options = call.options;
    NSString *type = options[@"type"] ? options[@"type"] : @"hi";
    NSString *key = [type isEqualToString:@"hi"] ? @"wood-hi" : @"wood-lo";
    
    id player = _metroPlayers[key];
    if (player) {
        SEL setTimeSel = NSSelectorFromString(@"setCurrentTime:");
        if ([player respondsToSelector:setTimeSel]) {
            typedef void (*SetTimeFn)(id, SEL, NSTimeInterval);
            SetTimeFn fn = (SetTimeFn)[player methodForSelector:setTimeSel];
            fn(player, setTimeSel, 0.0);
        }
        SEL playSel = NSSelectorFromString(@"play");
        if ([player respondsToSelector:playSel]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [player performSelector:playSel];
            #pragma clang diagnostic pop
        }
    }
    [call resolve];
}

- (void)releaseAllNotes:(CAPPluginCall *)call {
    SEL stopSel = NSSelectorFromString(@"stop");
    SEL isPlayingSel = NSSelectorFromString(@"isPlaying");
    
    for (NSMutableArray *pool in _samplePlayers.allValues) {
        for (id player in pool) {
            typedef BOOL (*IsPlayingFn)(id, SEL);
            IsPlayingFn fn = (IsPlayingFn)[player methodForSelector:isPlayingSel];
            if (fn(player, isPlayingSel)) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [player performSelector:stopSel];
                #pragma clang diagnostic pop
            }
        }
    }
    [call resolve];
}

@end

#import <Capacitor/Capacitor.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

CAP_PLUGIN(NativePDFPlugin, "NativePdf",
    CAP_PLUGIN_METHOD(openPdf, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(closePdf, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(jumpToPage, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setTheme, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setDrawingMode, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setBarsVisible, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setTopbarInset, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setBottomInset, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(updateDisplayMode, CAPPluginReturnPromise);
)


// C Function to configure AVAudioSession dynamically without AVFoundation headers
// Declared as a static C function to prevent linker dead-code stripping.
void configurePlaybackAudioSession(void) {
    Class audioSessionClass = NSClassFromString(@"AVAudioSession");
    if (!audioSessionClass) {
        void *handle = dlopen("AVFoundation", RTLD_NOW);
        if (!handle) {
            handle = dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation", RTLD_NOW);
        }
        audioSessionClass = NSClassFromString(@"AVAudioSession");
    }
    
    if (!audioSessionClass) return;
    
    SEL sharedSessionSel = NSSelectorFromString(@"sharedInstance");
    id sharedSession = nil;
    if ([audioSessionClass respondsToSelector:sharedSessionSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        sharedSession = [audioSessionClass performSelector:sharedSessionSel];
#pragma clang diagnostic pop
    }
    
    if (!sharedSession) return;
    
    // Configurar Categoría a Playback con MixWithOthers (1) + AllowBluetooth (4)
    // Esto evita que iOS envíe AudioSession::beginInterruption al WebContent process de WKWebView
    SEL setCategorySel = NSSelectorFromString(@"setCategory:withOptions:error:");
    if ([sharedSession respondsToSelector:setCategorySel]) {
        typedef BOOL (*SetCategoryFn)(id, SEL, NSString *, NSUInteger, NSError **);
        SetCategoryFn setCategory = (SetCategoryFn)[sharedSession methodForSelector:setCategorySel];
        NSError *err = nil;
        BOOL ok = setCategory(sharedSession, setCategorySel, @"AVAudioSessionCategoryPlayback", 1 | 4, &err);
        if (ok) {
            NSLog(@"🔊 [AudioSession] Categoría AVAudioSessionCategoryPlayback (MixWithOthers) configurada.");
        }
    } else {
        SEL fallbackSel = NSSelectorFromString(@"setCategory:error:");
        if ([sharedSession respondsToSelector:fallbackSel]) {
            typedef BOOL (*FallbackFn)(id, SEL, NSString *, NSError **);
            FallbackFn setCategory = (FallbackFn)[sharedSession methodForSelector:fallbackSel];
            NSError *err = nil;
            setCategory(sharedSession, fallbackSel, @"AVAudioSessionCategoryPlayback", &err);
        }
    }
}

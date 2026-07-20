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
    
    if (!audioSessionClass) {
        NSLog(@"⚠️ [AudioSession] Class AVAudioSession no encontrada");
        return;
    }
    
    SEL sharedSessionSel = NSSelectorFromString(@"sharedInstance");
    id sharedSession = nil;
    if ([audioSessionClass respondsToSelector:sharedSessionSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        sharedSession = [audioSessionClass performSelector:sharedSessionSel];
#pragma clang diagnostic pop
    }
    
    if (!sharedSession) {
        NSLog(@"⚠️ [AudioSession] No se pudo obtener sharedInstance");
        return;
    }
    
    // Configurar Categoría a Playback (ignora el interruptor de silencio)
    SEL setCategorySel = NSSelectorFromString(@"setCategory:error:");
    if ([sharedSession respondsToSelector:setCategorySel]) {
        typedef BOOL (*SetCategoryFn)(id, SEL, NSString *, NSError **);
        SetCategoryFn setCategory = (SetCategoryFn)[sharedSession methodForSelector:setCategorySel];
        NSError *err = nil;
        BOOL ok = setCategory(sharedSession, setCategorySel, @"AVAudioSessionCategoryPlayback", &err);
        if (!ok) {
            NSLog(@"⚠️ [AudioSession] Error al configurar category: %@", err);
        } else {
            NSLog(@"🔊 [AudioSession] Categoría AVAudioSessionCategoryPlayback configurada.");
        }
    }
    
    // Activar Sesión de Audio
    SEL setActiveSel = NSSelectorFromString(@"setActive:error:");
    if ([sharedSession respondsToSelector:setActiveSel]) {
        typedef BOOL (*SetActiveFn)(id, SEL, BOOL, NSError **);
        SetActiveFn setActive = (SetActiveFn)[sharedSession methodForSelector:setActiveSel];
        NSError *err = nil;
        BOOL ok = setActive(sharedSession, setActiveSel, YES, &err);
        if (!ok) {
            NSLog(@"⚠️ [AudioSession] Error al activar sesión: %@", err);
        } else {
            NSLog(@"🔊 [AudioSession] Sesión de Audio activada con éxito.");
        }
    }
}

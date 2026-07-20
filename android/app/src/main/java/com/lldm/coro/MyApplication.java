package com.lldm.coro;

import android.app.Application;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.initialization.InitializationStatus;
import com.google.android.gms.ads.initialization.OnInitializationCompleteListener;

public class MyApplication extends Application {
    private AppOpenManager appOpenManager;

    @Override
    public void onCreate() {
        super.onCreate();
        
        // Inicializar el SDK de anuncios a nivel nativo
        MobileAds.initialize(
            this,
            new OnInitializationCompleteListener() {
                @Override
                public void onInitializationComplete(InitializationStatus initializationStatus) {}
            });

        // Iniciar nuestro gestor de App Open Ad
        appOpenManager = new AppOpenManager(this);
    }
}

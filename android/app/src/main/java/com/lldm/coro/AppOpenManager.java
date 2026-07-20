package com.lldm.coro;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.appopen.AppOpenAd;

import java.util.Date;

public class AppOpenManager implements Application.ActivityLifecycleCallbacks {
    private static final String LOG_TAG = "AppOpenManager";
    private static final String AD_UNIT_ID = "ca-app-pub-1667188991926373/4859596502";
    
    private AppOpenAd appOpenAd = null;
    private AppOpenAd.AppOpenAdLoadCallback loadCallback;
    private final MyApplication myApplication;
    private Activity currentActivity;
    private boolean isShowingAd = false;
    private long loadTime = 0;
    
    // Condición solicitada: NO mostrar al iniciar por primera vez, solo al volver.
    private boolean isFirstLaunch = true;
    private int startedActivities = 0;

    public AppOpenManager(MyApplication myApplication) {
        this.myApplication = myApplication;
        this.myApplication.registerActivityLifecycleCallbacks(this);
        fetchAd();
    }

    public void fetchAd() {
        // Ads temporarily disabled by user request
        Log.d(LOG_TAG, "App Open Ads disabled.");
    }

    private AdRequest getAdRequest() {
        return new AdRequest.Builder().build();
    }

    private boolean wasLoadTimeLessThanNHoursAgo(long numHours) {
        long dateDifference = (new Date()).getTime() - this.loadTime;
        long numMilliSecondsPerHour = 3600000;
        return (dateDifference < (numMilliSecondsPerHour * numHours));
    }

    public boolean isAdAvailable() {
        return false; // Force disabled
    }

    public void showAdIfAvailable() {
        // Ads temporarily disabled by user request
        Log.d(LOG_TAG, "showAdIfAvailable bypassed (Ads disabled).");
    }

    @Override
    public void onActivityStarted(@NonNull Activity activity) {
        currentActivity = activity;
        startedActivities++;
        
        // Si startedActivities pasa de 0 a 1, la app acaba de venir al frente (foreground)
        if (startedActivities == 1) {
            if (isFirstLaunch) {
                // El usuario pidió expresamente no asustar con anuncios de buenas a primeras
                isFirstLaunch = false;
                Log.d(LOG_TAG, "Primer inicio detectado, saltando anuncio.");
            } else {
                showAdIfAvailable();
            }
        }
    }

    @Override
    public void onActivityStopped(@NonNull Activity activity) {
        startedActivities--;
    }

    @Override
    public void onActivityCreated(@NonNull Activity activity, @Nullable Bundle savedInstanceState) {}
    @Override
    public void onActivityResumed(@NonNull Activity activity) { currentActivity = activity; }
    @Override
    public void onActivityPaused(@NonNull Activity activity) {}
    @Override
    public void onActivitySaveInstanceState(@NonNull Activity activity, @NonNull Bundle outState) {}
    @Override
    public void onActivityDestroyed(@NonNull Activity activity) { 
        if (currentActivity == activity) {
            currentActivity = null; 
        }
    }
}

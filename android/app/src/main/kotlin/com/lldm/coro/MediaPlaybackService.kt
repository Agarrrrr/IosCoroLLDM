package com.lldm.coro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import java.io.File

class MediaPlaybackService : Service() {

    companion object {
        private const val CHANNEL_ID = "coro_lldm_media_playback"
        private const val NOTIFICATION_ID = 7742
        private const val ACTION_PLAY = "com.lldm.coro.action.PLAY"
        private const val ACTION_PAUSE = "com.lldm.coro.action.PAUSE"
        private const val ACTION_NEXT = "com.lldm.coro.action.NEXT"
        private const val ACTION_PREV = "com.lldm.coro.action.PREV"

        @Volatile
        var instance: MediaPlaybackService? = null
            private set

        @Volatile
        var commandListener: ((String, Map<String, Any>?) -> Unit)? = null

        private var cachedTitle: String = "Coro LLDM"
        private var cachedArtist: String = "Coro LLDM"
        private var cachedAlbum: String = "Coro LLDM"
        private var cachedDurationMs: Long = 0L
        private var cachedPositionMs: Long = 0L
        private var cachedIsPlaying: Boolean = false
        private var cachedCanSkipNext: Boolean = true
        private var cachedCanSkipPrev: Boolean = true
        private var cachedCanSeek: Boolean = true
        private var cachedArtworkPath: String? = null
        private var cachedArtworkBitmap: Bitmap? = null

        fun updateMetadata(
            context: Context,
            title: String,
            artist: String,
            album: String,
            durationMs: Long,
            positionMs: Long,
            isPlaying: Boolean,
            canSkipNext: Boolean,
            canSkipPrev: Boolean,
            canSeek: Boolean,
            artworkPath: String? = null,
        ) {
            cachedTitle = title
            cachedArtist = artist
            cachedAlbum = album
            cachedDurationMs = durationMs
            cachedPositionMs = positionMs
            cachedIsPlaying = isPlaying
            cachedCanSkipNext = canSkipNext
            cachedCanSkipPrev = canSkipPrev
            cachedCanSeek = canSeek

            if (artworkPath != cachedArtworkPath) {
                cachedArtworkPath = artworkPath
                cachedArtworkBitmap = if (!artworkPath.isNullOrEmpty()) {
                    try {
                        val file = File(artworkPath)
                        if (file.exists() && file.length() > 0) {
                            BitmapFactory.decodeFile(artworkPath)
                        } else null
                    } catch (_: Exception) {
                        null
                    }
                } else null
            }

            val svc = instance
            if (svc != null) {
                svc.applyState()
            } else {
                startServiceCompat(context)
            }
        }

        fun updatePlaybackState(
            context: Context,
            positionMs: Long,
            durationMs: Long,
            isPlaying: Boolean,
            canSkipNext: Boolean,
            canSkipPrev: Boolean,
            canSeek: Boolean,
        ) {
            cachedPositionMs = positionMs
            if (durationMs > 0) cachedDurationMs = durationMs
            cachedIsPlaying = isPlaying
            cachedCanSkipNext = canSkipNext
            cachedCanSkipPrev = canSkipPrev
            cachedCanSeek = canSeek

            val svc = instance
            if (svc != null) {
                svc.applyState()
            } else if (isPlaying) {
                startServiceCompat(context)
            }
        }

        fun beginTrackTransition(context: Context) {
            val svc = instance
            if (svc != null) {
                svc.acquireTransitionLocks()
            } else {
                startServiceCompat(context)
            }
        }

        fun endTrackTransition() {
            instance?.releaseTransitionLocksIfIdle()
        }

        fun stopSession(context: Context) {
            cachedIsPlaying = false
            instance?.stopSelfCleanly()
            context.stopService(Intent(context, MediaPlaybackService::class.java))
        }

        private fun startServiceCompat(context: Context) {
            try {
                val intent = Intent(context, MediaPlaybackService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {
            }
        }
    }

    private var mediaSession: MediaSession? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var isForeground = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        initLocks()
        initMediaSession()
        applyState()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> commandListener?.invoke("play", null)
            ACTION_PAUSE -> commandListener?.invoke("pause", null)
            ACTION_NEXT -> if (cachedCanSkipNext) commandListener?.invoke("next", null)
            ACTION_PREV -> if (cachedCanSkipPrev) commandListener?.invoke("previous", null)
        }
        applyState()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopSelfCleanly()
        if (instance === this) {
            instance = null
        }
        super.onDestroy()
    }

    private fun initLocks() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "CoroLLDM:MediaPlaybackWakeLock",
            ).apply {
                setReferenceCounted(false)
            }
        } catch (_: Exception) {
        }
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val lockType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                @Suppress("DEPRECATION")
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wm.createWifiLock(lockType, "CoroLLDM:MediaWifiLock").apply {
                setReferenceCounted(false)
            }
        } catch (_: Exception) {
        }
    }

    fun acquireTransitionLocks() {
        try {
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(60 * 60 * 1000L)
            }
            if (wifiLock?.isHeld == false) {
                wifiLock?.acquire()
            }
        } catch (_: Exception) {
        }
    }

    fun releaseTransitionLocksIfIdle() {
        if (!cachedIsPlaying) {
            releaseLocks()
        }
    }

    private fun releaseLocks() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        try {
            if (wifiLock?.isHeld == true) wifiLock?.release()
        } catch (_: Exception) {
        }
    }

    private fun initMediaSession() {
        val session = MediaSession(this, "CoroLLDMMediaSession")
        session.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                commandListener?.invoke("play", null)
            }

            override fun onPause() {
                commandListener?.invoke("pause", null)
            }

            override fun onSkipToNext() {
                if (cachedCanSkipNext) {
                    commandListener?.invoke("next", null)
                }
            }

            override fun onSkipToPrevious() {
                if (cachedCanSkipPrev) {
                    commandListener?.invoke("previous", null)
                }
            }

            override fun onSeekTo(pos: Long) {
                if (cachedCanSeek) {
                    commandListener?.invoke("seek", mapOf("positionMs" to pos))
                }
            }

            override fun onStop() {
                commandListener?.invoke("pause", null)
            }
        })
        session.isActive = true
        mediaSession = session
    }

    fun applyState() {
        val session = mediaSession ?: return
        if (cachedIsPlaying) {
            acquireTransitionLocks()
        } else {
            releaseLocks()
        }

        val metaBuilder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, cachedTitle)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, cachedArtist)
            .putString(MediaMetadata.METADATA_KEY_ALBUM, cachedAlbum)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, cachedDurationMs.coerceAtLeast(0L))

        val bmp = cachedArtworkBitmap ?: try {
            BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        } catch (_: Exception) {
            null
        }
        if (bmp != null) {
            metaBuilder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, bmp)
            metaBuilder.putBitmap(MediaMetadata.METADATA_KEY_ART, bmp)
        }
        session.setMetadata(metaBuilder.build())

        var actions = PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE
        if (cachedCanSkipNext) actions = actions or PlaybackState.ACTION_SKIP_TO_NEXT
        if (cachedCanSkipPrev) actions = actions or PlaybackState.ACTION_SKIP_TO_PREVIOUS
        if (cachedCanSeek) actions = actions or PlaybackState.ACTION_SEEK_TO

        val stateCode = if (cachedIsPlaying) {
            PlaybackState.STATE_PLAYING
        } else {
            PlaybackState.STATE_PAUSED
        }

        val pbState = PlaybackState.Builder()
            .setActions(actions)
            .setState(
                stateCode,
                cachedPositionMs.coerceAtLeast(0L),
                if (cachedIsPlaying) 1.0f else 0.0f,
                SystemClock.elapsedRealtime(),
            )
            .build()
        session.setPlaybackState(pbState)

        val notification = buildNotification(session)
        try {
            if (!isForeground) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                isForeground = true
            } else {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
        }
    }

    private fun buildNotification(session: MediaSession): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val prevPending = serviceActionPendingIntent(ACTION_PREV, 1)
        val playPausePending = serviceActionPendingIntent(
            if (cachedIsPlaying) ACTION_PAUSE else ACTION_PLAY,
            2,
        )
        val nextPending = serviceActionPendingIntent(ACTION_NEXT, 3)

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(cachedTitle)
            .setContentText(cachedArtist)
            .setSubText(cachedAlbum)
            .setContentIntent(contentPendingIntent)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(cachedIsPlaying)
            .setOnlyAlertOnce(true)

        val artBmp = cachedArtworkBitmap ?: try {
            BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)
        } catch (_: Exception) {
            null
        }
        if (artBmp != null) {
            builder.setLargeIcon(artBmp)
        }

        val compactIndices = mutableListOf<Int>()
        var actionIndex = 0
        if (cachedCanSkipPrev) {
            builder.addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_previous,
                    "Previous",
                    prevPending,
                ).build(),
            )
            compactIndices.add(actionIndex++)
        }
        builder.addAction(
            Notification.Action.Builder(
                if (cachedIsPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (cachedIsPlaying) "Pause" else "Play",
                playPausePending,
            ).build(),
        )
        compactIndices.add(actionIndex++)

        if (cachedCanSkipNext) {
            builder.addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_next,
                    "Next",
                    nextPending,
                ).build(),
            )
            compactIndices.add(actionIndex++)
        }

        val mediaStyle = Notification.MediaStyle()
            .setMediaSession(session.sessionToken)
            .setShowActionsInCompactView(*compactIndices.toIntArray())
        builder.setStyle(mediaStyle)

        return builder.build()
    }

    private fun serviceActionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, MediaPlaybackService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Reproductor Coro LLDM",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Controles de reproducción en pantalla de bloqueo y Bluetooth"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun stopSelfCleanly() {
        releaseLocks()
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
            mediaSession = null
        } catch (_: Exception) {
        }
        try {
            if (isForeground) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                isForeground = false
            }
        } catch (_: Exception) {
        }
    }
}

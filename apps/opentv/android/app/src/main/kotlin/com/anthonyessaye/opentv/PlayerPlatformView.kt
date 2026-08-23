package com.anthonyessaye.opentv

import android.content.Context
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import android.view.TextureView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * The Android half of the playback surface.
 *
 * Answers the same method channel contract as the tvOS implementation — same
 * view type, same creation params, same state keys — so the Dart side needs
 * no knowledge of which engine is underneath. That is the whole point of the
 * seam: one interface, two engines.
 *
 * Media3 rather than libVLC. ExoPlayer demuxes MPEG-TS and Matroska natively,
 * which is precisely what AVPlayer cannot do and why Apple needs libVLC. On
 * Android the platform player already covers the catalogue, and it integrates
 * with the system's audio focus, hardware decoding and playback notifications
 * in a way a bundled engine does not.
 */
class PlayerPlatformView(
    context: Context,
    viewId: Int,
    args: Any?,
    messenger: BinaryMessenger,
) : PlatformView, Player.Listener {

    private val player: ExoPlayer

    /**
     * A TextureView rather than Media3's PlayerView, and the distinction is
     * not cosmetic.
     *
     * Flutter hosts an Android platform view inside a virtual display, and a
     * SurfaceView — which PlayerView uses by default — does not render into
     * one. The result is a correctly initialised player producing frames into
     * a surface nobody composites: audio plays, state advances, and the
     * screen stays black. A TextureView draws through the normal view
     * hierarchy and composites correctly.
     *
     * Nothing is lost by dropping PlayerView: the transport chrome is drawn
     * in Flutter, so its controls and layout were being suppressed anyway.
     */
    private val view: TextureView
    private val channel = MethodChannel(messenger, "opentv/player/$viewId")

    /** Reported to Dart so a test can assert on decode progress. */
    private var framesSeen = false
    private var lastError: String? = null

    init {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        val options = params["options"] as? Map<String, String> ?: emptyMap()

        // Providers frequently refuse to serve a stream without the user agent
        // or referrer their playlist named, so those have to reach the HTTP
        // layer rather than being dropped on the floor.
        val http = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .apply {
                options["http-user-agent"]?.let { setUserAgent(it) }
                val headers = buildMap {
                    options["http-referrer"]?.let { put("Referer", it) }
                }
                if (headers.isNotEmpty()) setDefaultRequestProperties(headers)
            }

        player = ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(http))
            .build()
            .also { it.addListener(this) }

        view = TextureView(context)
        player.setVideoTextureView(view)

        channel.setMethodCallHandler(::handle)

        (params["url"] as? String)?.let { play(it) }
    }

    override fun getView(): View = view

    override fun dispose() {
        channel.setMethodCallHandler(null)
        player.release()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val url = (call.arguments as? Map<*, *>)?.get("url") as? String
                if (url == null) {
                    if (player.playbackState != Player.STATE_IDLE) player.play()
                } else {
                    play(url)
                }
                result.success(null)
            }
            "pause" -> { player.pause(); result.success(null) }
            "stop" -> { player.stop(); result.success(null) }
            "state" -> result.success(snapshot())
            else -> result.notImplemented()
        }
    }

    private fun play(url: String) {
        framesSeen = false
        lastError = null
        player.setMediaItem(MediaItem.fromUri(url))
        player.prepare()
        player.playWhenReady = true
    }

    /** Everything the Dart chrome needs, in the same shape tvOS returns. */
    private fun snapshot(): Map<String, Any?> {
        val size: VideoSize = player.videoSize
        // A live stream reports an unset duration; the Dart side is told
        // liveness explicitly by the catalogue and does not infer it, but the
        // value still has to be a number rather than a sentinel.
        val length = player.duration
        return mapOf(
            "state" to describe(player.playbackState),
            "isPlaying" to player.isPlaying,
            "hasVideoOut" to (size.width > 0),
            "framesSeen" to framesSeen,
            "width" to size.width,
            "height" to size.height,
            "position" to if (length > 0) player.currentPosition.toFloat() / length else 0f,
            "timeMs" to player.currentPosition,
            "lengthMs" to if (length == androidx.media3.common.C.TIME_UNSET) 0L else length,
            "audioTracks" to countTracks(androidx.media3.common.C.TRACK_TYPE_AUDIO),
            "videoTracks" to countTracks(androidx.media3.common.C.TRACK_TYPE_VIDEO),
            "subtitleTracks" to countTracks(androidx.media3.common.C.TRACK_TYPE_TEXT),
            "error" to lastError,
        )
    }

    private fun countTracks(type: Int): Int =
        player.currentTracks.groups.count { it.type == type }

    private fun describe(state: Int): String = when (state) {
        Player.STATE_IDLE -> if (lastError != null) "error" else "opening"
        Player.STATE_BUFFERING -> "buffering"
        Player.STATE_READY -> if (player.playWhenReady) "playing" else "paused"
        Player.STATE_ENDED -> "ended"
        else -> "opening"
    }

    // MARK: Player.Listener

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        if (videoSize.width > 0) framesSeen = true
        channel.invokeMethod("state", snapshot())
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        channel.invokeMethod("state", snapshot())
    }

    override fun onPlayerError(error: PlaybackException) {
        // Named rather than swallowed: on a real provider a dead channel is
        // routine, and the interface says so instead of spinning forever.
        lastError = error.errorCodeName
        channel.invokeMethod("state", snapshot())
    }
}

/** Builds [PlayerPlatformView]s for Flutter's `AndroidView`. */
class PlayerPlatformViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        PlayerPlatformView(context, viewId, args, messenger)
}

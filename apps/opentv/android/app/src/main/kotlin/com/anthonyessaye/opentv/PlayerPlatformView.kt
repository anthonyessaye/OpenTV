package com.anthonyessaye.opentv

import android.content.Context
import android.view.SurfaceView
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
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
 * no knowledge of which engine is underneath.
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
     * A SurfaceView, and getting here took two attempts.
     *
     * Flutter's default platform-view mode cannot host a SurfaceView, so the
     * first working version used a TextureView. That produced a picture, and
     * broke 4K in two ways at once: HDR came out dark, because a TextureView
     * is composited by the GPU as an ordinary SDR texture and the PQ or HLG
     * transfer function never reaches the display pipeline; and 4K stuttered,
     * because every frame took an extra GPU copy that television silicon is
     * not built to absorb.
     *
     * The Dart side now creates this view in hybrid composition, which puts it
     * in the real Android view hierarchy. Here that means a SurfaceView can be
     * used again — able to take a hardware overlay plane, and able to carry
     * HDR10 and HLG through to the panel.
     *
     * It sits inside a FrameLayout so the aspect-ratio modes have something to
     * resize against without disturbing the platform view's own bounds.
     */
    private val container = FrameLayout(context)
    private val surface = SurfaceView(context)

    private val channel = MethodChannel(messenger, "opentv/player/$viewId")

    private var framesSeen = false
    private var lastError: String? = null

    /** How the picture is fitted to the panel. See [applyAspect]. */
    private var aspectMode = "fit"

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

        container.addView(surface)
        player.setVideoSurfaceView(surface)

        channel.setMethodCallHandler(::handle)

        (params["url"] as? String)?.let { play(it) }
    }

    override fun getView(): View = container

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

            // The tracks a stream actually carries, for the selection sheet.
            "tracks" -> result.success(tracks())

            // Picking one. A null id means "let the player choose", which is
            // how a viewer turns subtitles back off.
            "selectTrack" -> {
                val args = call.arguments as? Map<*, *>
                val type = args?.get("type") as? String
                val id = args?.get("id") as? String
                if (type == null) {
                    result.error("bad-args", "type required", null)
                    return
                }
                selectTrack(type, id)
                result.success(null)
            }

            "setAspect" -> {
                aspectMode = (call.arguments as? Map<*, *>)?.get("mode") as? String ?: "fit"
                applyAspect()
                result.success(null)
            }

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

    // MARK: tracks

    private fun trackType(name: String): Int = when (name) {
        "audio" -> C.TRACK_TYPE_AUDIO
        "text" -> C.TRACK_TYPE_TEXT
        "video" -> C.TRACK_TYPE_VIDEO
        else -> C.TRACK_TYPE_UNKNOWN
    }

    /**
     * Every selectable track, described well enough to choose between.
     *
     * The id encodes the group and the track within it, because that pair is
     * what an override needs and neither half identifies a track on its own.
     */
    private fun tracks(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        player.currentTracks.groups.forEachIndexed { groupIndex, group ->
            val kind = when (group.type) {
                C.TRACK_TYPE_AUDIO -> "audio"
                C.TRACK_TYPE_TEXT -> "text"
                C.TRACK_TYPE_VIDEO -> "video"
                else -> return@forEachIndexed
            }
            for (trackIndex in 0 until group.length) {
                if (!group.isTrackSupported(trackIndex)) continue
                val format = group.getTrackFormat(trackIndex)
                out.add(
                    mapOf(
                        "type" to kind,
                        "id" to "$groupIndex:$trackIndex",
                        "label" to describe(format, kind),
                        "language" to format.language,
                        "selected" to group.isTrackSelected(trackIndex),
                        "codec" to format.codecs,
                        "channels" to format.channelCount.takeIf { it != Format.NO_VALUE },
                        "width" to format.width.takeIf { it != Format.NO_VALUE },
                        "height" to format.height.takeIf { it != Format.NO_VALUE },
                        "hdr" to hdrName(format),
                    )
                )
            }
        }
        return out
    }

    /**
     * The dynamic range a video track carries, or null for ordinary SDR.
     *
     * Reported so the interface can say what is playing rather than leaving a
     * viewer to wonder why one channel looks different from another — and so
     * a picture that comes out wrong can be diagnosed from the screen instead
     * of from a log.
     */
    private fun hdrName(format: Format): String? = when (format.colorInfo?.colorTransfer) {
        C.COLOR_TRANSFER_ST2084 -> "HDR10"
        C.COLOR_TRANSFER_HLG -> "HLG"
        else -> null
    }

    private fun describe(format: Format, kind: String): String {
        val parts = mutableListOf<String>()
        format.label?.let { parts.add(it) }
        format.language?.let { if (parts.isEmpty()) parts.add(it) }

        when (kind) {
            "audio" -> {
                when (format.channelCount) {
                    1 -> parts.add("Mono")
                    2 -> parts.add("Stereo")
                    6 -> parts.add("5.1")
                    8 -> parts.add("7.1")
                }
                format.codecs?.substringBefore('.')?.let { parts.add(it) }
            }
            "video" -> {
                if (format.height != Format.NO_VALUE) parts.add("${format.height}p")
                hdrName(format)?.let { parts.add(it) }
            }
        }

        return parts.filter { it.isNotBlank() }.joinToString(" · ")
            .ifBlank { if (kind == "text") "Subtitles" else "Track" }
    }

    private fun selectTrack(type: String, id: String?) {
        val mediaType = trackType(type)
        if (mediaType == C.TRACK_TYPE_UNKNOWN) return

        if (id == null) {
            // Clearing the override hands the choice back to the player's own
            // selector, which is also how subtitles are turned off.
            player.trackSelectionParameters = player.trackSelectionParameters
                .buildUpon()
                .clearOverridesOfType(mediaType)
                .setTrackTypeDisabled(mediaType, type == "text")
                .build()
            return
        }

        val (groupIndex, trackIndex) = id.split(':').let {
            (it.getOrNull(0)?.toIntOrNull() ?: return) to
                (it.getOrNull(1)?.toIntOrNull() ?: return)
        }
        val group = player.currentTracks.groups.getOrNull(groupIndex) ?: return

        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setTrackTypeDisabled(mediaType, false)
            .setOverrideForType(
                TrackSelectionOverride(group.mediaTrackGroup, listOf(trackIndex))
            )
            .build()
    }

    // MARK: aspect ratio

    /**
     * How the picture meets the panel.
     *
     * Four modes, because IPTV carries a mixture no single rule handles:
     * `fit` letterboxes and is correct; `fill` crops to the panel, which
     * viewers reach for on 4:3 material they would rather not see pillarboxed;
     * `stretch` distorts, and exists because some providers letterbox 16:9
     * into a 4:3 raster and stretching is the only way to undo it; `original`
     * shows the raster at its own size.
     */
    private fun applyAspect() {
        val size = player.videoSize
        if (size.width == 0 || size.height == 0) return

        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
        surface.layoutParams = params

        // Media3's own resize modes live on PlayerView, which this does not
        // use, so the equivalent is applied to the surface directly.
        val viewWidth = container.width.takeIf { it > 0 } ?: return
        val viewHeight = container.height.takeIf { it > 0 } ?: return
        val videoAspect = size.width.toFloat() / size.height * size.pixelWidthHeightRatio
        val viewAspect = viewWidth.toFloat() / viewHeight

        when (aspectMode) {
            "stretch" -> params.width = viewWidth.also { params.height = viewHeight }
            "original" -> {
                params.width = size.width
                params.height = size.height
            }
            "fill" -> {
                if (videoAspect > viewAspect) {
                    params.height = viewHeight
                    params.width = (viewHeight * videoAspect).toInt()
                } else {
                    params.width = viewWidth
                    params.height = (viewWidth / videoAspect).toInt()
                }
            }
            else -> {
                if (videoAspect > viewAspect) {
                    params.width = viewWidth
                    params.height = (viewWidth / videoAspect).toInt()
                } else {
                    params.height = viewHeight
                    params.width = (viewHeight * videoAspect).toInt()
                }
            }
        }
        surface.layoutParams = params
    }

    /** Everything the Dart chrome needs, in the same shape tvOS returns. */
    private fun snapshot(): Map<String, Any?> {
        val size: VideoSize = player.videoSize
        val length = player.duration
        val video = player.videoFormat
        return mapOf(
            "state" to describeState(player.playbackState),
            "isPlaying" to player.isPlaying,
            "hasVideoOut" to (size.width > 0),
            "framesSeen" to framesSeen,
            "width" to size.width,
            "height" to size.height,
            "position" to if (length > 0) player.currentPosition.toFloat() / length else 0f,
            "timeMs" to player.currentPosition,
            "lengthMs" to if (length == C.TIME_UNSET) 0L else length,
            "audioTracks" to countTracks(C.TRACK_TYPE_AUDIO),
            "videoTracks" to countTracks(C.TRACK_TYPE_VIDEO),
            "subtitleTracks" to countTracks(C.TRACK_TYPE_TEXT),
            // Named on screen so a viewer can tell HDR from SDR, and so a
            // picture that looks wrong can be diagnosed without a log.
            "dynamicRange" to video?.let { hdrName(it) },
            "videoCodec" to video?.codecs?.substringBefore('.'),
            "aspectMode" to aspectMode,
            "error" to lastError,
        )
    }

    private fun countTracks(type: Int): Int =
        player.currentTracks.groups.count { it.type == type }

    private fun describeState(state: Int): String = when (state) {
        Player.STATE_IDLE -> if (lastError != null) "error" else "opening"
        Player.STATE_BUFFERING -> "buffering"
        Player.STATE_READY -> if (player.playWhenReady) "playing" else "paused"
        Player.STATE_ENDED -> "ended"
        else -> "opening"
    }

    // MARK: Player.Listener

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        if (videoSize.width > 0) framesSeen = true
        applyAspect()
        channel.invokeMethod("state", snapshot())
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        channel.invokeMethod("state", snapshot())
    }

    override fun onTracksChanged(tracks: Tracks) {
        // The chrome shows AUDIO and SUBTITLES only when there is a choice to
        // make, so it has to hear when that changes.
        channel.invokeMethod("state", snapshot())
    }

    override fun onPlayerError(error: PlaybackException) {
        // Named rather than swallowed: on a real provider a dead channel is
        // routine, and the interface says so instead of spinning forever.
        lastError = error.errorCodeName
        channel.invokeMethod("state", snapshot())
    }
}

/** Builds [PlayerPlatformView]s for Flutter's platform view host. */
class PlayerPlatformViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        PlayerPlatformView(context, viewId, args, messenger)
}

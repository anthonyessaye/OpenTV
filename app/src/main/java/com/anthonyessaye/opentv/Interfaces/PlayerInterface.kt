package com.anthonyessaye.opentv.Interfaces

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import androidx.lifecycle.lifecycleScope
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Models.Series.Episode
import com.anthonyessaye.opentv.Models.Series.SeriesDetails
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistory
import com.anthonyessaye.opentv.Persistence.History.SeriesHistory.SeriesHistory
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.Persistence.Server.Server
import com.anthonyessaye.opentv.Persistence.User.User
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.net.URI

interface PlayerInterface {
    fun buildStreamURI(server: Server, loggedInUser: User, stream_type: StreamType, stream_id: Int, container_extension: String): Uri {
        return ("${server.buildURL()}/${stream_type.type}/${loggedInUser.username}/" +
                "${loggedInUser.password}/${stream_id}.${container_extension}").toUri()
    }
    fun play(context: Context, streamURI: Uri) {
        val intent = Intent(context, dev.anilbeesetti.nextplayer.feature.player.PlayerActivity::class.java).apply {
            data = streamURI
        }

        context.startActivity(intent)
    }

    fun cache(context: Context, item: Any, stream_type: StreamType) {
        when(stream_type) {
            StreamType.LIVE -> {
                DatabaseManager().openDatabase(context) { db ->
                    val liveStream = item as LiveStream
                    val history = db.liveHistoryDao().findById(liveStream.stream_id.toString())

                    // Write history to disk
                    CoroutineScope(Dispatchers.IO).launch {
                        val liveHistory = LiveHistory(
                            liveStream.stream_id,
                            liveStream.name,
                            (System.currentTimeMillis() / 1000).toString(),
                            liveStream.stream_icon
                        )

                        if (history == null)
                            db.liveHistoryDao().insertTop(10, liveHistory)

                        else
                            db.liveHistoryDao().update((System.currentTimeMillis() / 1000).toString(), liveStream.stream_id)
                    }
                }
            }

            StreamType.SERIES -> {
                DatabaseManager().openDatabase(context) { db ->
                    val episodeData = item as Pair<Series, Episode>
                    val series = episodeData.first
                    val episode = episodeData.second
                    val history = db.seriesHistoryDao().findById(episode.id)

                    // Write history to disk
                    CoroutineScope(Dispatchers.IO).launch {
                        val seriesHistory = SeriesHistory(episode.id.toInt(),
                            episode.title,
                            episode.container_extension,
                            (System.currentTimeMillis() / 1000).toString(),
                            series.cover,
                            "0",
                            series.series_id.toString())

                        if (history == null)
                            db.seriesHistoryDao().insertTop(50, seriesHistory)
                        else
                            db.seriesHistoryDao().updateLastWatched(
                                (System.currentTimeMillis() / 1000).toString(),
                                episode.id.toInt()
                            )

                    }
                }
            }

            StreamType.MOVIE -> {
                DatabaseManager().openDatabase(context) { db ->
                    val movie = item as Movie
                    val history = db.movieHistoryDao().findById(movie.stream_id.toString())

                    // Write history to disk
                    CoroutineScope(Dispatchers.IO).launch {
                        val movieHistory = MovieHistory(
                            movie.stream_id,
                            movie.name,
                            movie.container_extension,
                            (System.currentTimeMillis() / 1000).toString(),
                            movie.stream_icon,
                            "0"
                        )

                        if (history == null)
                            db.movieHistoryDao().insertTop(50, movieHistory)
                        else
                            db.movieHistoryDao().updateLastWatched(
                                (System.currentTimeMillis() / 1000).toString(),
                                movie.stream_id
                            )
                    }
                }
            }
        }
    }
}
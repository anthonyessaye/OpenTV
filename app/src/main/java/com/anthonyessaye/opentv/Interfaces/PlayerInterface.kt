package com.anthonyessaye.opentv.Interfaces

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import androidx.lifecycle.lifecycleScope
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistory
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

    fun cache(context: Context, stream_id: Int, stream_name: String, stream_icon: String?, container_extension: String, stream_type: StreamType) {
        when(stream_type) {
            StreamType.LIVE -> {
                DatabaseManager().openDatabase(context) { db ->
                    val history = db.liveHistoryDao().findById(stream_id.toString())

                    // Write history to disk
                    CoroutineScope(Dispatchers.IO).launch {
                        val liveHistory = LiveHistory(
                            stream_id,
                            stream_name,
                            (System.currentTimeMillis() / 1000).toString(),
                            stream_icon
                        )

                        if (history == null)
                            db.liveHistoryDao().insertTop(10, liveHistory)

                        else
                            db.liveHistoryDao().update((System.currentTimeMillis() / 1000).toString(), stream_id)
                    }
                }
            }

            StreamType.SERIES -> {
                DatabaseManager().openDatabase(context) { db ->
                    val history = db.ser().findById(stream_id.toString())

                    // Write history to disk
                    CoroutineScope(Dispatchers.IO).launch {
                        val movieHistory = MovieHistory(
                            stream_id,
                            stream_name,
                            container_extension,
                            (System.currentTimeMillis() / 1000).toString(),
                            stream_icon,
                            "0"
                        )

                        if (history == null)
                            db.movieHistoryDao().insertTop(50, movieHistory)
                        else
                            db.movieHistoryDao().updateLastWatched(
                                (System.currentTimeMillis() / 1000).toString(),
                                stream_id
                            )
                    }
                }
            }

            StreamType.MOVIE -> {
                DatabaseManager().openDatabase(context) { db ->
                    val history = db.movieHistoryDao().findById(stream_id.toString())

                    // Write history to disk
                    CoroutineScope(Dispatchers.IO).launch {
                        val movieHistory = MovieHistory(
                            stream_id,
                            stream_name,
                            container_extension,
                            (System.currentTimeMillis() / 1000).toString(),
                            stream_icon,
                            "0"
                        )

                        if (history == null)
                            db.movieHistoryDao().insertTop(50, movieHistory)
                        else
                            db.movieHistoryDao().updateLastWatched(
                                (System.currentTimeMillis() / 1000).toString(),
                                stream_id
                            )
                    }
                }
            }
        }
    }
}
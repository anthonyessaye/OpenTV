package com.anthonyessaye.opentv

import android.app.Application
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllEpisodesActivity
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import dagger.hilt.android.HiltAndroidApp
import dev.anilbeesetti.nextplayer.core.common.player.PlayerCommonInterface
import dev.anilbeesetti.nextplayer.core.common.player.PlayerCommonInterfaceObserver
import kotlinx.coroutines.runBlocking
import java.lang.System
import kotlin.Pair
import kotlin.collections.first

@HiltAndroidApp
class OpenTVApplication: Application(), PlayerCommonInterface {
    override fun onCreate() {
        super.onCreate()
        playerCommonInterfaceObserverInstace.registerObserver(this)
    }


    override fun cache(stream_id: String, stream_type: String, position: Long) {
       if (stream_type == StreamType.SERIES.toString().lowercase()) {
           DatabaseManager().openDatabase(this) { db ->
               db.seriesHistoryDao().updatePosition(position.toString(), stream_id.toInt())
               db.seriesHistoryDao().updateLastWatched((System.currentTimeMillis()/1000).toString(), stream_id.toInt())
           }
       }

        else if (stream_type == StreamType.MOVIE.toString()) {

       }
    }

    override fun getPosition(stream_id: String, stream_type: String): String {
        if (stream_type == StreamType.SERIES.toString().lowercase()) {
            var position = "-1"

            runBlocking {
                DatabaseManager().openDatabase(this@OpenTVApplication) { db ->
                    val cacheObject = db.seriesHistoryDao().findById(stream_id)
                    position = cacheObject!!.position
                }
            }

            return position
        }

        else if (stream_type == StreamType.MOVIE.toString()) {
            return "0"
        }

        return "0"
    }


    companion object {
        val playerCommonInterfaceObserverInstace = PlayerCommonInterfaceObserver.getInstance()
    }
}


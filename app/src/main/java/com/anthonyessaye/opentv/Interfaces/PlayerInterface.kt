package com.anthonyessaye.opentv.Interfaces

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.net.toUri
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Persistence.Server.Server
import com.anthonyessaye.opentv.Persistence.User.User
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
}
package dev.anilbeesetti.nextplayer.core.common.player

interface PlayerCommonInterface {
    fun cache(stream_id: String, stream_type: String, position: Long)
    fun getPosition(stream_id: String, stream_type: String): String
}

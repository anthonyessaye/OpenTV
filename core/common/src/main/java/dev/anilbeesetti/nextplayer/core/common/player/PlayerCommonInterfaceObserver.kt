package dev.anilbeesetti.nextplayer.core.common.player

import dev.anilbeesetti.nextplayer.core.common.player.PlayerCommonInterfaceObserver

class PlayerCommonInterfaceObserver private constructor() {
    private val observers: kotlin.collections.MutableList<PlayerCommonInterface>

    init {
        observers = java.util.ArrayList<PlayerCommonInterface>()
    }

    fun registerObserver(observer: PlayerCommonInterface?) {
        observers.add(observer!!)
    }

    fun removeObserver(observer: PlayerCommonInterface?) {
        observers.remove(observer)
    }

    fun notifyObserversToCache(
        stream_id: kotlin.String,
        stream_type: kotlin.String,
        position: kotlin.Long
    ) {
        for (observer in observers) {
            observer.cache(stream_id, stream_type, position)
        }
    }

    fun notifyObserversToGetPosition(
        stream_id: kotlin.String,
        stream_type: kotlin.String
    ): kotlin.String {
        for (observer in observers) {
            return observer.getPosition(stream_id, stream_type)
        }

        return "0"
    }

    companion object {
        private var instance: PlayerCommonInterfaceObserver? = null

        fun getInstance(): PlayerCommonInterfaceObserver {
            if (instance == null) {
                instance = PlayerCommonInterfaceObserver()
            }

            return instance!!
        }
    }
}

package com.anthonyessaye.opentv.Models

import java.io.Serializable

class Genre : Serializable {
    var id: Int = 0
        private set
    var name: String? = null
        private set

    constructor()

    fun setId(id: Int): Genre {
        this.id = id
        return this
    }

    fun setName(name: String?): Genre {
        this.name = name
        return this
    }
}

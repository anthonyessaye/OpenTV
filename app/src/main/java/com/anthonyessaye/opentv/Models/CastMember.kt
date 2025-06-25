package com.anthonyessaye.opentv.Models

import java.io.Serializable

class CastMember : Serializable {
    var id: Int = 0
        private set
    var character: String? = null
        private set
    var name: String? = null
        private set
    var order: Int = 0
        private set
    var cast_id: Int = 0
        private set
    var credit_id: String? = null
        private set
    var profile_path: String? = null
        private set

    fun setId(id: Int): CastMember {
        this.id = id
        return this
    }

    fun setCastId(cast_id: Int): CastMember {
        this.cast_id = cast_id
        return this
    }

    fun setCharacter(character: String?): CastMember {
        this.character = character
        return this
    }

    fun setCreditId(credit_id: String?): CastMember {
        this.credit_id = credit_id
        return this
    }

    fun setName(name: String?): CastMember {
        this.name = name
        return this
    }

    fun setOrder(order: Int): CastMember {
        this.order = order
        return this
    }

    fun setProfilePath(profile_path: String?): CastMember {
        this.profile_path = profile_path
        return this
    }
}

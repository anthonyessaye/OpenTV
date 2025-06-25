package com.anthonyessaye.opentv.Models

class CreditsResponse {
    var id: Int = 0
        private set
    private var cast: MutableList<CastMember?>? = null
    private var crew: MutableList<CrewMember?>? = null

    fun setId(id: Int): CreditsResponse {
        this.id = id
        return this
    }

    fun getCast(): MutableList<CastMember?>? {
        return cast
    }

    fun setCast(cast: MutableList<CastMember?>?): CreditsResponse {
        this.cast = cast
        return this
    }

    fun getCrew(): MutableList<CrewMember?>? {
        return crew
    }

    fun setCrew(crew: MutableList<CrewMember?>?): CreditsResponse {
        this.crew = crew
        return this
    }
}

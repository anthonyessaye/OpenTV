package com.anthonyessaye.opentv.Models.Series

import java.io.Serializable

data class Season(var name: String,
    var episode_count: String,
    var overview: String,
    var air_date: String,
    var cover: String,
    var cover_tmdb: String,
    var season_number: Int,
    var cover_big: String,
    var releaseDate: String,
    var duration: String): Serializable

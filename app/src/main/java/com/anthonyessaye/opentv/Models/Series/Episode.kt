package com.anthonyessaye.opentv.Models.Series

import java.io.Serializable

data class Episode(val id: String,
    val episode_num: Int,
    val title: String,
    val container_extension: String,
    val info: EpisodeInfo,
    val custom_sid: String?,
    val added: String,
    val season: Int,
    val direct_source: String): Serializable
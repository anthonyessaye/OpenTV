package com.anthonyessaye.opentv.Models.Series

import com.anthonyessaye.opentv.Models.Series.Episode
import com.github.kittinunf.fuel.core.ResponseDeserializable
import com.google.gson.Gson
import com.google.gson.JsonArray
import java.io.Serializable
import kotlin.String
import kotlin.collections.List
import kotlin.collections.Map

data class SeriesDetailsAlternative(val seasons: List<Season>,
                                    val info: SeasonInfo,
                                    val episodes: List<List<Episode>>): Serializable {

    fun translateToSeriesDetails(): SeriesDetails {
        var episodesMap: Map<String, List<Episode>> = emptyMap()
        var count = 1

        for (episode in episodes) {
            episodesMap = episodesMap.plus(Pair(count.toString(), episode))
            count += 1
        }

        return SeriesDetails(seasons, info, episodesMap)
    }
}
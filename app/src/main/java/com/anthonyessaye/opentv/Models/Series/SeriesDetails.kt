package com.anthonyessaye.opentv.Models.Series

import com.github.kittinunf.fuel.core.ResponseDeserializable
import com.google.gson.Gson
import com.google.gson.JsonArray
import java.io.Serializable

data class SeriesDetails(val seasons: List<Season>,
                         val info: SeasonInfo,
                         val episodes: Map<String, List<Episode>>): Serializable {

    class Deserializer : ResponseDeserializable<SeriesDetails> {
        override fun deserialize(content: String) =
            Gson().fromJson(content, SeriesDetails::class.java)
    }
 }
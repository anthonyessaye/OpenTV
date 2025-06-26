package com.anthonyessaye.opentv.REST

import app.moviebase.tmdb.model.TmdbMovie
import com.anthonyessaye.opentv.Activities.DetailActivities.MovieResponse
import com.anthonyessaye.opentv.DataClasses.UserAndServer
import com.github.kittinunf.fuel.Fuel
import com.github.kittinunf.fuel.core.ResponseResultOf
import com.github.kittinunf.fuel.gson.responseObject
import com.github.kittinunf.result.Result
import com.google.gson.Gson
import com.google.gson.JsonParser
import kotlinx.serialization.json.JsonObject


object TMDBRESTHandler {
    public fun getMovieRecommendations(movieID: Int): ResponseResultOf<MovieResponse> {
        return Fuel
            .get("https://api.themoviedb.org/3/movie/${movieID}/recommendations")
            .header(Pair<String,String>("Authorization","Bearer ${APIKeys.TMDB_READ_TOKEN}"))
            .responseObject<MovieResponse>()
    }
}
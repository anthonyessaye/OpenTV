package com.anthonyessaye.opentv.REST

import com.anthonyessaye.opentv.Models.MovieResponse
import com.github.kittinunf.fuel.Fuel
import com.github.kittinunf.fuel.core.ResponseResultOf
import com.github.kittinunf.fuel.gson.responseObject


object TMDBRESTHandler {
    public fun getMovieRecommendations(movieID: Int): ResponseResultOf<MovieResponse> {
        return Fuel
            .get("https://api.themoviedb.org/3/movie/${movieID}/recommendations")
            .header(Pair<String,String>("Authorization","Bearer ${APIKeys.TMDB_READ_TOKEN}"))
            .responseObject<MovieResponse>()
    }
}
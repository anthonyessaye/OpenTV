package com.anthonyessaye.opentv.REST

import com.anthonyessaye.opentv.Builders.XtreamBuilder
import com.anthonyessaye.opentv.DataClasses.UserAndServer
import com.anthonyessaye.opentv.Models.Series.SeriesDetails
import com.anthonyessaye.opentv.Persistence.Categories.LiveCategory.LiveCategory
import com.anthonyessaye.opentv.Persistence.Categories.MovieCategory.MovieCategory
import com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory.SeriesCategory
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.Persistence.Server.Server
import com.anthonyessaye.opentv.Persistence.User.User
import com.github.kittinunf.fuel.Fuel
import com.github.kittinunf.fuel.coroutines.awaitObjectResponse
import com.github.kittinunf.fuel.gson.responseObject
import com.github.kittinunf.result.Result

object RESTHandler {

    object UserREST {
        public fun getUserAndServerInfo(
            xtream: XtreamBuilder,
            completion: (user: User?, server: Server?) -> Unit
        ) {
            Fuel.get(xtream.getUserInfoURL())
                .responseObject<UserAndServer> { request, response, result ->
                    when (result) {
                        is Result.Failure -> {
                            val ex = result.getException()
                            completion(null, null)
                        }

                        is Result.Success -> {
                            val data = result.get()
                            completion(
                                result.component1()!!.user_info,
                                result.component1()!!.server_info
                            )
                        }
                    }

                }
        }
    }

    object LiveStreamREST {
        public fun getLiveStreamData(
            xtream: XtreamBuilder,
            completion: (liveStreams: List<LiveStream>) -> Unit
        ) {

            Fuel.get(xtream.getAllLiveStreamURL())
                .responseObject<List<LiveStream>> { request, response, result ->
                    when (result) {
                        is Result.Failure -> {
                            val ex = result.getException()
                            completion(emptyList())
                        }

                        is Result.Success -> {
                            val data = result.get()
                            completion(result.component1()!!)
                        }
                    }
                }
        }

        public fun getLiveStreamCategories(
            xtream: XtreamBuilder,
            completion: (liveStreams: List<LiveCategory>) -> Unit
        ) {

            Fuel.get(xtream.getAllLiveCategoriesURL())
                .responseObject<List<LiveCategory>> { request, response, result ->
                    when (result) {
                        is Result.Failure -> {
                            val ex = result.getException()
                            completion(emptyList())
                        }

                        is Result.Success -> {
                            val data = result.get()
                            completion(result.component1()!!)
                        }
                    }
                }
        }
    }

    object MovieREST {
        public fun getMovieData(
            xtream: XtreamBuilder,
            completion: (movies: List<Movie>) -> Unit
        ) {

            Fuel.get(xtream.getAllMoviesURL())
                .responseObject<List<Movie>> { request, response, result ->
                    when (result) {
                        is Result.Failure -> {
                            val ex = result.getException()
                            completion(emptyList())
                        }

                        is Result.Success -> {
                            val data = result.get()
                            completion(result.component1()!!)
                        }
                    }
                }
        }

        public fun getMovieCategories(
            xtream: XtreamBuilder,
            completion: (movieCategories: List<MovieCategory>) -> Unit
        ) {

            Fuel.get(xtream.getAllMovieCategoriesURL())
                .responseObject<List<MovieCategory>> { request, response, result ->
                    when (result) {
                        is Result.Failure -> {
                            val ex = result.getException()
                            completion(emptyList())
                        }

                        is Result.Success -> {
                            val data = result.get()
                            completion(result.component1()!!)
                        }
                    }
                }
        }

    }

    object SeriesREST {
        public fun getSeriesData(
            xtream: XtreamBuilder,
            completion: (series: List<Series>) -> Unit
        ) {

            Fuel.get(xtream.getAllSeriesURL())
                .responseObject<List<Series>> { request, response, result ->
                    when (result) {
                        is Result.Failure -> {
                            val ex = result.getException()
                            completion(emptyList())
                        }

                        is Result.Success -> {
                            val data = result.get()
                            completion(result.component1()!!)
                        }
                    }
                }
        }

        public fun getSeriesCategories(
            xtream: XtreamBuilder,
            completion: (seriesCateogires: List<SeriesCategory>) -> Unit
        ) {

            Fuel.get(xtream.getAllSeriesCategoriesURL())
                .responseObject<List<SeriesCategory>> { request, response, result ->
                    when (result) {
                        is Result.Failure -> {
                            val ex = result.getException()
                            completion(emptyList())
                        }

                        is Result.Success -> {
                            val data = result.get()
                            completion(result.component1()!!)
                        }
                    }
                }
        }

        suspend fun getSeriesDetails(
            xtream: XtreamBuilder,
            series_id: String
        ) : SeriesDetails? = Fuel.get(xtream.getStreamInfoForSpecificSeries(series_id)).awaitObjectResponse<SeriesDetails>(SeriesDetails.Deserializer()).third


    }
}
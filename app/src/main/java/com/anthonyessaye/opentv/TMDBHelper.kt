package com.anthonyessaye.opentv

object TMDBHelper {
    const val DISK_CACHE_SIZE: Long = (50 * 1024 * 1024).toLong() // 50MBs
    const val BACKDROP_URL: String = "https://image.tmdb.org/t/p/w1280/"
    const val POSTER_URL: String = "https://image.tmdb.org/t/p/w500/"
    const val NOW_PLAYING: String = "movie/now_playing"
    const val POPULAR: String = "movie/popular"
    const val TOP_RATED: String = "movie/top_rated"
    const val UPCOMING: String = "movie/upcoming"
    const val MOVIE: String = "movie/"
    const val TV_TOP_RATED: String = "tv/top_rated"
    const val TV_POPULAR: String = "tv/popular"
    const val TV_ON_THE_AIR: String = "tv/on_the_air"
    const val TV_AIRING_TODAY: String = "tv/airing_today"
    const val SEARCH_MOVIE: String = "search/movie"
}
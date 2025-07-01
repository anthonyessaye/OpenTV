package com.anthonyessaye.opentv.Models.Series

import java.io.Serializable

data class EpisodeInfo(val kinopoisk_url: String,
                       val tmdb_id: String,
                       val name: String,
                       val o_name: String,
                       val cover_big: String,
                       val movie_image: String,
                       val releasedate: String,
                       val episode_run_time: Int,
                       val youtube_trailer: String,
                       val director: String,
                       val actors: String,
                       val overview: String,
                       val plot: String,
                       val age: String,
                       val mpaa_rating: String,
                       val rating_count_kinopoisk: Int,
                       val genre: String,
                       val backdrop_path: List<String>,
                       val duration_secs: Int,
                       val duration: String,
                       val video: EpisodeVideo,
                       val audio: EpisodeAudio,
                       val bitrate: Int,
                       val rating: Float): Serializable



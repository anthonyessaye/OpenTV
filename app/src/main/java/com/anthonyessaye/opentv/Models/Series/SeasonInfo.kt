package com.anthonyessaye.opentv.Models.Series

import java.io.Serializable

data class SeasonInfo(var name: String,
                      var cover: String,
                      var plot: String,
                      var cast: String,
                      var director: String,
                      var genre: String,
                      var releaseDate: String,
                      var release_date : String,
                      var last_modified: String,
                      var rating: String,
                      var rating_5based: String,
                      var backdrop_path: List<String>,
                      var tmdb: String,
                      var youtube_trailer: String,
                      var episode_run_time: String,
                      var category_id: String,
                      var category_ids: List<Int>): Serializable
package com.anthonyessaye.opentv.Persistence.Series

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
class Series(
    @PrimaryKey var series_id: Int,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "num") val num: Int,
    @ColumnInfo(name = "cover") val cover: String?,
    @ColumnInfo(name = "plot") val plot: String?,
    @ColumnInfo(name = "cast") val cast: String?,
    @ColumnInfo(name = "director") val director: String?,
    @ColumnInfo(name = "genre") val genre: String?,
    @ColumnInfo(name = "releaseDate") val releaseDate: String?,
    @ColumnInfo(name = "release_date") val release_date: String?,
    @ColumnInfo(name = "last_modified") val last_modified: String?,
    @ColumnInfo(name = "rating") val rating: String?,
    @ColumnInfo(name = "rating_5based") val rating_5based: String?,
    @ColumnInfo(name = "backdrop_path") val backdrop_path: Any?, //Uses any because some providers return an array while others return a string
    @ColumnInfo(name = "youtube_trailer") val youtube_trailer: String?,
    @ColumnInfo(name = "tmdb") val tmdb: String?,
    @ColumnInfo(name = "episode_run_time") val episode_run_time: String?,
    @ColumnInfo(name = "category_id") val category_id: String?,
    @ColumnInfo(name = "category_ids") val category_ids: List<String>?
) : Serializable {



}
package com.anthonyessaye.opentv.Persistence.Movie

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
class Movie(
    @PrimaryKey var stream_id: Int,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "num") val num: Int,
    @ColumnInfo(name = "stream_type") val stream_type: String,
    @ColumnInfo(name = "stream_icon") val stream_icon: String?,
    @ColumnInfo(name = "rating") val rating: String,
    @ColumnInfo(name = "rating_5based") val rating_5based: String,
    @ColumnInfo(name = "tmdb") val tmdb: String?,
    @ColumnInfo(name = "trailer") val trailer: String?,
    @ColumnInfo(name = "added") val added: String,
    @ColumnInfo(name = "is_adult") val is_adult: Int,
    @ColumnInfo(name = "category_id") val category_id: String?,
    @ColumnInfo(name = "category_ids") val category_ids: List<String>?,
    @ColumnInfo(name = "container_extension") val container_extension: String,
    @ColumnInfo(name = "custom_sid") val custom_sid: String?,
    @ColumnInfo(name = "direct_source") val direct_source: String?
) : Serializable

package com.anthonyessaye.opentv.Persistence.LiveStream

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
class LiveStream(
    @PrimaryKey var stream_id: Int,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "num") val num: Int,
    @ColumnInfo(name = "stream_type") val stream_type: String,
    @ColumnInfo(name = "stream_icon") val stream_icon: String?,
    @ColumnInfo(name = "epg_channel_id") val epg_channel_id: String?,
    @ColumnInfo(name = "added") val added: String,
    @ColumnInfo(name = "is_adult") val is_adult: Int,
    @ColumnInfo(name = "category_id") val category_id: String?,
    @ColumnInfo(name = "category_ids") val category_ids: List<String>?,
    @ColumnInfo(name = "custom_sid") val custom_sid: String?,
    @ColumnInfo(name = "tv_archive") val tv_archive: Int,
    @ColumnInfo(name = "direct_source") val direct_source: String?,
    @ColumnInfo(name = "tv_archive_duration") val tv_archive_duration: Int
) : Serializable


package com.anthonyessaye.opentv.Persistence.History.SeriesHistory

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
class SeriesHistory(
    @PrimaryKey var stream_id: Int,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "container_extension") val container_extension: String,
    @ColumnInfo(name = "last_watched") val last_watched: String,
    @ColumnInfo(name = "stream_icon") val stream_icon: String?,
    @ColumnInfo(name = "position") val position: String,
    @ColumnInfo(name = "series_id") val series_id: String
) : Serializable

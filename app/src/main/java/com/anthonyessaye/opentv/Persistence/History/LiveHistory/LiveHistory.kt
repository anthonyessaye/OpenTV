package com.anthonyessaye.opentv.Persistence.History.LiveHistory

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
class LiveHistory(
    @PrimaryKey var stream_id: Int,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "last_watched") val last_watched: String,
    @ColumnInfo(name = "stream_icon") val stream_icon: String?
) : Serializable
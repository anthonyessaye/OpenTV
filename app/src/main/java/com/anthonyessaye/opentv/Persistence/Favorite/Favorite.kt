package com.anthonyessaye.opentv.Persistence.Favorite

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import java.io.Serializable

@Entity
class Favorite(
    @PrimaryKey var stream_id: Int,
    @ColumnInfo(name = "name") val name: String,
    @ColumnInfo(name = "stream_icon") val stream_icon: String?,
    @ColumnInfo(name = "stream_type") val stream_type: String
) : Serializable
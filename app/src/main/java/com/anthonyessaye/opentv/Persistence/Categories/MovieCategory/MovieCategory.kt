package com.anthonyessaye.opentv.Persistence.Categories.MovieCategory

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity
class MovieCategory(
    @PrimaryKey var category_id: String,
    @ColumnInfo(name = "category_name") val category_name: String,
    @ColumnInfo(name = "parent_id") val parent_id: Int
)
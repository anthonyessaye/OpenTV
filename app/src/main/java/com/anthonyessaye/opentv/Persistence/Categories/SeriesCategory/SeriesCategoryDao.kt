package com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

@Dao
interface SeriesCategoryDao {
    @Query("SELECT * FROM SeriesCategory")
    fun getAll(): List<SeriesCategory>

    @Query("SELECT * FROM SeriesCategory WHERE category_id IN (:categoryIds)")
    fun loadAllByIds(categoryIds: IntArray): List<SeriesCategory>

    @Query("SELECT * FROM SeriesCategory WHERE category_name LIKE :name")
    fun findByName(name: String): SeriesCategory

    @Insert
    fun insertAll(vararg seriesCategories: SeriesCategory)

    @Delete
    fun delete(seriesCategory: SeriesCategory)

    @Query("DELETE FROM SeriesCategory")
    fun deleteTable(): Int
}
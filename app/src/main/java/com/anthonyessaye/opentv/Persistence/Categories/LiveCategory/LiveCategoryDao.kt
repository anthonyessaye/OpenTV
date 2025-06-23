package com.anthonyessaye.opentv.Persistence.Categories.LiveCategory

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

@Dao
interface LiveCategoryDao {
    @Query("SELECT * FROM LiveCategory")
    fun getAll(): List<LiveCategory>

    @Query("SELECT * FROM LiveCategory WHERE category_id IN (:categoryIds)")
    fun loadAllByIds(categoryIds: IntArray): List<LiveCategory>

    @Query("SELECT * FROM LiveCategory WHERE category_name LIKE :name")
    fun findByName(name: String): LiveCategory

    @Insert
    fun insertAll(vararg liveCategories: LiveCategory)

    @Delete
    fun delete(liveCategory: LiveCategory)

    @Query("DELETE FROM LiveCategory")
    fun deleteTable(): Int
}
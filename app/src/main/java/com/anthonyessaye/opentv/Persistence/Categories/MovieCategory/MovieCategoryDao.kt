package com.anthonyessaye.opentv.Persistence.Categories.MovieCategory

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

@Dao
interface MovieCategoryDao {
    @Query("SELECT * FROM MovieCategory")
    fun getAll(): List<MovieCategory>

    @Query("SELECT * FROM MovieCategory WHERE category_id IN (:categoryIds)")
    fun loadAllByIds(categoryIds: IntArray): List<MovieCategory>

    @Query("SELECT * FROM MovieCategory WHERE category_name LIKE :name")
    fun findByName(name: String): MovieCategory

    @Insert
    fun insertAll(vararg movieCategories: MovieCategory)

    @Delete
    fun delete(movieCategory: MovieCategory)

    @Query("DELETE FROM MovieCategory")
    fun deleteTable(): Int
}
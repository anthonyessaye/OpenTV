package com.anthonyessaye.opentv.Persistence.Series

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import com.anthonyessaye.opentv.Persistence.Movie.Movie

@Dao
interface SeriesDao {

    @Query("SELECT * FROM Series")
    fun getAll(): List<Series>

    @Query("SELECT * FROM Series WHERE series_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<Series>

    @Query("SELECT * FROM Series WHERE name LIKE :name")
    fun findByName(name: String): Series

    @Query("SELECT * FROM Series WHERE series_id LIKE :Id")
    fun findById(Id: String): Series

    @Query("SELECT * FROM Series WHERE category_id LIKE :id")
    fun findByCategoryId(id: String): List<Series>


    @Insert
    fun insertAll(vararg series: Series)

    @Delete
    fun delete(series: Series)

    @Query("DELETE FROM Series")
    fun deleteTable(): Int
}
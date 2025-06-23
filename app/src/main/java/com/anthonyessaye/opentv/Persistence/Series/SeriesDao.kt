package com.anthonyessaye.opentv.Persistence.Series

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

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

    @Insert
    fun insertAll(vararg series: Series)

    @Delete
    fun delete(series: Series)

    @Query("DELETE FROM Series")
    fun deleteTable(): Int
}
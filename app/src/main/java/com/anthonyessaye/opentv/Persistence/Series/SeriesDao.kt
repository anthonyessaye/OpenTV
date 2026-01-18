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

    @Query("""
    SELECT Series.*, (LENGTH(Series.name) - LENGTH(REPLACE(LOWER(Series.name), LOWER(:name), ''))) AS match_count
    FROM Series
    JOIN SeriesFts ON Series.rowid = SeriesFts.docid
    WHERE SeriesFts MATCH :name
    ORDER BY match_count DESC, Series.name ASC
    LIMIT :limit
""")
    fun search(name: String, limit: Int): List<Series>

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
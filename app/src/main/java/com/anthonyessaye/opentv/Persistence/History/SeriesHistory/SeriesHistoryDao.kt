package com.anthonyessaye.opentv.Persistence.History.SeriesHistory

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface SeriesHistoryDao {
    @Query("SELECT * FROM SeriesHistory")
    fun getAll(): List<SeriesHistory>

    @Query("SELECT * FROM SeriesHistory WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<SeriesHistory>

    @Query("SELECT * FROM SeriesHistory WHERE name LIKE :name")
    fun findByName(name: String): SeriesHistory

    @Query("SELECT * FROM SeriesHistory WHERE stream_id LIKE :id")
    fun findById(id: String): SeriesHistory

    @Transaction
    fun insertTop(top: Int, history: SeriesHistory) {
        insertAll(history)
        deleteRowsNotTop(top)
    }

    @Query("DELETE FROM SeriesHistory WHERE last_watched NOT IN ( " +
            "SELECT last_watched FROM SeriesHistory ORDER BY last_watched DESC LIMIT :top);")
    fun deleteRowsNotTop(top: Int)

    @Query("UPDATE SeriesHistory SET last_watched = :last_watched WHERE stream_id = :stream_id")
    fun updateLastWatched(last_watched: String, stream_id: Int)

    @Query("UPDATE SeriesHistory SET position = :position WHERE stream_id = :stream_id")
    fun updatePosition(position: String, stream_id: Int)

    @Insert
    fun insertAll(vararg history: SeriesHistory)

    @Delete
    fun delete(seriesHistory: SeriesHistory)

    @Query("DELETE FROM SeriesHistory")
    fun deleteTable(): Int
}
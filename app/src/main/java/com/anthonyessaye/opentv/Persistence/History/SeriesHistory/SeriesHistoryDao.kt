package com.anthonyessaye.opentv.Persistence.History.SeriesHistory

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction

/**
 * In the future it might be worth creating a table just for series with
 * something like series_id and List<Episode Ids Watched> and then query
 * that for history and keep this table short with only the tracking info
 * of the latest episode.
 *
 * That will definitely make the operations faster on the long run when
 * the database is heavy. Food for thought.
 */
@Dao
interface SeriesHistoryDao {
    @Query("SELECT * FROM (SELECT * FROM SeriesHistory ORDER BY last_watched DESC) GROUP BY series_id")
    fun getAll(): List<SeriesHistory>

    @Query("SELECT * FROM SeriesHistory WHERE series_id IN (:seriesId)")
    fun loadAllByIds(seriesId: IntArray): List<SeriesHistory>

    @Query("SELECT * FROM SeriesHistory WHERE name LIKE :name")
    fun findByName(name: String): SeriesHistory?

    @Query("SELECT * FROM SeriesHistory WHERE stream_id LIKE :id")
    fun findById(id: String): SeriesHistory?

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
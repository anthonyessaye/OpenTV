package com.anthonyessaye.opentv.Persistence.History.MovieHistory

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface MovieHistoryDao {
    @Query("SELECT * FROM MovieHistory")
    fun getAll(): List<MovieHistory>

    @Query("SELECT * FROM MovieHistory WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<MovieHistory>

    @Query("SELECT * FROM MovieHistory WHERE name LIKE :name")
    fun findByName(name: String): MovieHistory

    @Query("SELECT * FROM MovieHistory WHERE stream_id LIKE :id")
    fun findById(id: String): MovieHistory

    @Transaction
    fun insertTop(top: Int, history: MovieHistory) {
        insertAll(history)
        deleteRowsNotTop(top)
    }

    @Query("DELETE FROM MovieHistory WHERE last_watched NOT IN ( " +
            "SELECT last_watched FROM MovieHistory ORDER BY last_watched DESC LIMIT :top);")
    fun deleteRowsNotTop(top: Int)

    @Query("UPDATE MovieHistory SET last_watched = :last_watched WHERE stream_id = :stream_id")
    fun updateLastWatched(last_watched: String, stream_id: Int)

    @Query("UPDATE MovieHistory SET position = :position WHERE stream_id = :stream_id")
    fun updatePosition(position: String, stream_id: Int)

    @Insert
    fun insertAll(vararg history: MovieHistory)

    @Delete
    fun delete(moveHistory: MovieHistory)

    @Query("DELETE FROM MovieHistory")
    fun deleteTable(): Int
}
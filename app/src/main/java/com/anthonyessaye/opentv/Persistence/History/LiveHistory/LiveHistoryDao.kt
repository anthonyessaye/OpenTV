package com.anthonyessaye.opentv.Persistence.History.LiveHistory

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface LiveHistoryDao {
    @Query("SELECT * FROM LiveHistory")
    fun getAll(): List<LiveHistory>

    @Query("SELECT * FROM LiveHistory WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<LiveHistory>

    @Query("SELECT * FROM LiveHistory WHERE name LIKE :name")
    fun findByName(name: String): LiveHistory

    @Query("SELECT * FROM LiveHistory WHERE stream_id LIKE :id")
    fun findById(id: String): LiveHistory

    @Transaction
    fun insertTop(top: Int, history: LiveHistory) {
        insertAll(history)
        deleteRowsNotTop(top)
    }

    @Query("DELETE FROM LiveHistory WHERE last_watched NOT IN ( " +
            "SELECT last_watched FROM LiveHistory ORDER BY last_watched DESC LIMIT :top);")
    fun deleteRowsNotTop(top: Int)

    @Query("UPDATE LiveHistory SET last_watched = :last_watched WHERE stream_id = :stream_id")
    fun update(last_watched: String, stream_id: Int)

    @Insert
    fun insertAll(vararg history: LiveHistory)

    @Delete
    fun delete(liveHistory: LiveHistory)

    @Query("DELETE FROM LiveHistory")
    fun deleteTable(): Int
}
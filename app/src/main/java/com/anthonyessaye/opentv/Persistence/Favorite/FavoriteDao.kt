package com.anthonyessaye.opentv.Persistence.Favorite

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory

@Dao
interface FavoriteDao {
    @Query("SELECT * FROM Favorite")
    fun getAll(): List<Favorite>

    @Query("SELECT * FROM Favorite WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<Favorite>

    @Query("SELECT * FROM Favorite WHERE name LIKE :name")
    fun findByName(name: String): List<Favorite>?

    @Query("SELECT * FROM Favorite WHERE stream_type LIKE :stream_type")
    fun findByType(stream_type: String): List<Favorite>?

    @Query("SELECT * FROM Favorite WHERE stream_id LIKE :id")
    fun findById(id: String): Favorite?

    @Insert
    fun insertAll(vararg favorite: Favorite)

    @Delete
    fun delete(favorite: Favorite)

    @Query("DELETE FROM Favorite")
    fun deleteTable(): Int
}
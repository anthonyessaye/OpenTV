package com.anthonyessaye.opentv.Persistence.LiveStream

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

@Dao
interface LiveStreamDao {

    @Query("SELECT * FROM LiveStream")
    fun getAll(): List<LiveStream>

    @Query("SELECT * FROM LiveStream WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<LiveStream>

    @Query("SELECT * FROM LiveStream WHERE name LIKE :name")
    fun findByExactName(name: String): LiveStream

    @Query("SELECT * FROM LiveStream WHERE name LIKE '%' || :name || '%' COLLATE NOCASE LIMIT :limit")
    fun findByLikeName(name: String, limit: Int): List<LiveStream>

    @Query("SELECT * FROM LiveStream WHERE name LIKE '%' || :name COLLATE NOCASE LIMIT :limit")
    fun findByStartsWithName(name: String, limit: Int): List<LiveStream>

    @Query("SELECT * FROM LiveStream WHERE name LIKE :name || '%' COLLATE NOCASE LIMIT :limit")
    fun findByEndsWithName(name: String, limit: Int): List<LiveStream>

    @Query("SELECT * FROM LiveStream WHERE category_id LIKE :id")
    fun findByCategoryId(id: String): List<LiveStream>?

    @Query("SELECT * FROM LiveStream WHERE stream_id LIKE :id")
    fun findById(id: String): LiveStream?

    @Insert
    fun insertAll(vararg streams: LiveStream)

    @Delete
    fun delete(liveStream: LiveStream)

    @Query("DELETE FROM LiveStream")
    fun deleteTable(): Int
}
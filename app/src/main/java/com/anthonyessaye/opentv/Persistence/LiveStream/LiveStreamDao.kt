package com.anthonyessaye.opentv.Persistence.LiveStream

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface LiveStreamDao {

    @Query("SELECT * FROM LiveStream")
    fun getAll(): List<LiveStream>

    @Query("SELECT * FROM LiveStream WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<LiveStream>

    @Query("""
    SELECT LiveStream.*, (LENGTH(LiveStream.name) - LENGTH(REPLACE(LOWER(LiveStream.name), LOWER(:name), ''))) AS match_count
    FROM LiveStream
    JOIN LiveStreamFts ON LiveStream.rowid = LiveStreamFts.docid
    WHERE LiveStreamFts MATCH :name
    ORDER BY match_count DESC, LiveStream.name ASC
    LIMIT :limit
""")
    fun search(name: String, limit: Int): List<LiveStream>

    @Query("SELECT * FROM LiveStream WHERE category_id LIKE :id")
    fun findByCategoryId(id: String): List<LiveStream>?

    @Query("SELECT * FROM LiveStream WHERE stream_id LIKE :id")
    fun findById(id: String): LiveStream?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insertAll(vararg streams: LiveStream)

    @Delete
    fun delete(liveStream: LiveStream)

    @Query("DELETE FROM LiveStream")
    fun deleteTable(): Int
}
package com.anthonyessaye.opentv.Persistence.Movie

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream

@Dao
interface MovieDao {

    @Query("SELECT * FROM Movie")
    fun getAll(): List<Movie>

    @Query("SELECT * FROM Movie WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<Movie>

    @Query("SELECT * FROM Movie WHERE name LIKE :name")
    fun findByExactName(name: String): Movie

    @Query("SELECT * FROM Movie WHERE name LIKE '%' || :name || '%' COLLATE NOCASE LIMIT :limit")
    fun findByLikeName(name: String, limit: Int): List<Movie>

    @Query("SELECT * FROM Movie WHERE category_id LIKE :id")
    fun findByCategoryId(id: String): List<Movie>

    @Query("SELECT * FROM Movie WHERE stream_id LIKE :id")
    fun findById(id: String): Movie

    @Insert
    fun insertAll(vararg movies: Movie)

    @Delete
    fun delete(movie: Movie)

    @Query("DELETE FROM Movie")
    fun deleteTable(): Int
}
package com.anthonyessaye.opentv.Persistence.Movie

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

@Dao
interface MovieDao {

    @Query("SELECT * FROM Movie")
    fun getAll(): List<Movie>

    @Query("SELECT * FROM Movie WHERE stream_id IN (:streamIds)")
    fun loadAllByIds(streamIds: IntArray): List<Movie>

    @Query("""
    SELECT Movie.*, (LENGTH(Movie.name) - LENGTH(REPLACE(LOWER(Movie.name), LOWER(:name), ''))) AS match_count
    FROM Movie
    JOIN MovieFts ON Movie.rowid = MovieFts.docid
    WHERE MovieFts MATCH :name
    ORDER BY match_count DESC, Movie.name ASC
    LIMIT :limit
""")
    fun search(name: String, limit: Int): List<Movie>

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
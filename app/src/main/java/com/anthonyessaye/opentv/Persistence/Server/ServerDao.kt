package com.anthonyessaye.opentv.Persistence.Server

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

@Dao
interface ServerDao {
    @Query("SELECT * FROM Server")
    fun getAll(): List<Server>

    @Insert
    fun insertAll(vararg servers: Server)

    @Delete
    fun delete(server: Server)

    @Query("DELETE FROM Server")
    fun deleteTable(): Int
}
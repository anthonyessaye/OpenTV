package com.anthonyessaye.opentv.Persistence.User

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.TypeConverter
import com.google.gson.Gson

@Entity
class User(
    @PrimaryKey var username: String,
    @ColumnInfo(name = "password") val password: String,
    @ColumnInfo(name = "message") val message: String,
    @ColumnInfo(name = "auth") val auth: Int,
    @ColumnInfo(name = "status") val status: String,
    @ColumnInfo(name = "exp_date") val exp_date: String,
    @ColumnInfo(name = "is_trial") val is_trial: String,
    @ColumnInfo(name = "active_cons") val active_cons: String,
    @ColumnInfo(name = "created_at") val created_at: String,
    @ColumnInfo(name = "max_connections") val max_connections: String,
    @ColumnInfo(name = "allowed_output_formats") val allowed_output_formats: List<String>

)

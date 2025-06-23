package com.anthonyessaye.opentv.Persistence.Server

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity
class Server(
    @PrimaryKey var url: String,
    @ColumnInfo(name = "port") val port: String,
    @ColumnInfo(name = "https_port") val https_port: String,
    @ColumnInfo(name = "server_protocol") val server_protocol: String,
    @ColumnInfo(name = "rtmp_port") val rtmp_port: String,
    @ColumnInfo(name = "timezone") val timezone: String,
    @ColumnInfo(name = "timestamp_now") val timestamp_now: Int,
    @ColumnInfo(name = "time_now") val time_now: String,
    @ColumnInfo(name = "process") val process: Boolean
) {

    fun buildURL(): String {
        return "$server_protocol://$url:$port"
    }
}
package com.anthonyessaye.opentv.Persistence.Converters

import androidx.room.TypeConverter
import com.google.gson.Gson

object StringArrayConverter {
    @TypeConverter
    fun arrayToJson(value: Array<String>?) = Gson().toJson(value)

    @TypeConverter
    fun jsonToArray(value: String?) = Gson().fromJson(value, Array<String>::class.java)
}
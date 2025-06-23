package com.anthonyessaye.opentv.Persistence.Converters

import androidx.room.TypeConverter
import com.google.gson.Gson

object StringListConverter {
    @TypeConverter
    fun listToJson(value: Any) = Gson().toJson(value)

    @TypeConverter
    fun jsonToList(value: String?): List<String> {
        if (value.isNullOrEmpty())
            return emptyList()

        return Gson().fromJson(value, Array<String>::class.java).toList()
    }
}
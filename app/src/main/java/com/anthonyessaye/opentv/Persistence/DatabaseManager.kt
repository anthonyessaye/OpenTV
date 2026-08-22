package com.anthonyessaye.opentv.Persistence

import android.content.Context
import androidx.room.Room
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking


class DatabaseManager {

    fun openDatabase(context: Context, completion: (appData: AppDatabase) -> Unit) {
        runBlocking {
            launch(Dispatchers.IO) {
                completion(getInstance(context))
            }
        }
    }

    companion object {
        @Volatile
        private var instance: AppDatabase? = null

        // Room instances are designed to be singletons. Building one per call opened a new
        // connection to the same file from every call site.
        private fun getInstance(context: Context): AppDatabase {
            return instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java, "open-tv-db"
                ).build().also { instance = it }
            }
        }
    }

}

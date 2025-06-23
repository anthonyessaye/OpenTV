package com.anthonyessaye.opentv.Persistence

import android.content.Context
import androidx.room.Room
import androidx.room.migration.Migration
import com.anthonyessaye.opentv.Persistence.Migrations.MigrationFrom1To2
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking


class DatabaseManager {
    val MIGRATION_1_2: Migration = MigrationFrom1To2()

    fun openDatabase(context: Context, completion: (appData: AppDatabase) -> Unit) {
        runBlocking {
            launch(Dispatchers.IO) {
                val db = Room.databaseBuilder(
                    context,
                    AppDatabase::class.java, "open-tv-db"
                ).addMigrations(MIGRATION_1_2)
                    .fallbackToDestructiveMigration(true)
                    .build()

                completion(db)
            }
        }
    }

}
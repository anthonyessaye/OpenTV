package com.anthonyessaye.opentv.Interfaces

import android.content.Context
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.Favorite.Favorite
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

interface FavoriteInterface {
    fun addOrDeleteFavorite(context: Context, favorite: Favorite) {
        DatabaseManager().openDatabase(context) { db ->
            val favoriteCache = db.favoriteDao().findById(favorite.stream_id.toString())

            CoroutineScope(Dispatchers.IO).launch {
                if (favoriteCache == null)
                    db.favoriteDao().insertAll(favorite)

                else
                    db.favoriteDao().delete(favoriteCache)
            }
        }
    }

    fun getFavoritesByStreamType(context: Context, stream_type: String, completion: (favorites: List<Favorite>?) -> Unit) {
        DatabaseManager().openDatabase(context) { db ->
            completion(db.favoriteDao().findByType(stream_type))
        }
    }
}
package com.anthonyessaye.opentv.Persistence

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.anthonyessaye.opentv.Persistence.Categories.LiveCategory.LiveCategory
import com.anthonyessaye.opentv.Persistence.Categories.LiveCategory.LiveCategoryDao
import com.anthonyessaye.opentv.Persistence.Categories.MovieCategory.MovieCategory
import com.anthonyessaye.opentv.Persistence.Categories.MovieCategory.MovieCategoryDao
import com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory.SeriesCategory
import com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory.SeriesCategoryDao
import com.anthonyessaye.opentv.Persistence.Converters.StringArrayConverter
import com.anthonyessaye.opentv.Persistence.Converters.StringListConverter
import com.anthonyessaye.opentv.Persistence.Favorite.Favorite
import com.anthonyessaye.opentv.Persistence.Favorite.FavoriteDao
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistoryDao
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistory
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistoryDao
import com.anthonyessaye.opentv.Persistence.History.SeriesHistory.SeriesHistory
import com.anthonyessaye.opentv.Persistence.History.SeriesHistory.SeriesHistoryDao
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStreamDao
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Movie.MovieDao
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.Persistence.Series.SeriesDao
import com.anthonyessaye.opentv.Persistence.Server.Server
import com.anthonyessaye.opentv.Persistence.Server.ServerDao
import com.anthonyessaye.opentv.Persistence.User.User
import com.anthonyessaye.opentv.Persistence.User.UserDao

@Database(entities = [LiveStream::class,
                      Movie::class,
                      Series::class,
                      User::class,
                      Server::class,
                      LiveCategory::class,
                      MovieCategory::class,
                      SeriesCategory::class,
                      LiveHistory::class,
                      MovieHistory::class,
                      SeriesHistory::class,
                      Favorite::class], version = 1)

@TypeConverters(StringListConverter::class, StringArrayConverter::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun liveStreamDao(): LiveStreamDao
    abstract fun userDao(): UserDao
    abstract fun serverDao(): ServerDao
    abstract fun liveStreamCategoryDao(): LiveCategoryDao
    abstract fun movieCategoryDao(): MovieCategoryDao
    abstract fun seriesCategoryDao(): SeriesCategoryDao
    abstract fun movieDao(): MovieDao
    abstract fun seriesDao(): SeriesDao
    abstract fun liveHistoryDao(): LiveHistoryDao
    abstract fun movieHistoryDao(): MovieHistoryDao
    abstract fun seriesHistoryDao(): SeriesHistoryDao
    abstract fun favoriteDao(): FavoriteDao
}
package com.anthonyessaye.opentv.Persistence

import com.anthonyessaye.opentv.Persistence.Categories.LiveCategory.LiveCategory
import com.anthonyessaye.opentv.Persistence.Categories.LiveCategory.LiveCategoryDao
import com.anthonyessaye.opentv.Persistence.Categories.MovieCategory.MovieCategory
import com.anthonyessaye.opentv.Persistence.Categories.MovieCategory.MovieCategoryDao
import com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory.SeriesCategory
import com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory.SeriesCategoryDao
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStreamDao
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Movie.MovieDao
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.Persistence.Series.SeriesDao
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object DataParser {
    object LiveStreamRESTParser {
        suspend fun parseLiveStream(liveStreamDao: LiveStreamDao, liveStreams: List<LiveStream>): Boolean =
            withContext(Dispatchers.IO) {
                if (liveStreams.isNotEmpty()) {
                    liveStreamDao.deleteTable()
                    liveStreamDao.insertAll(*liveStreams.toTypedArray())

                    return@withContext true
                }

                return@withContext false
            }

        suspend fun parseLiveStreamCategory(liveCategoryDao: LiveCategoryDao, categories: List<LiveCategory>): Boolean =
            withContext(Dispatchers.IO) {
                if (categories.isNotEmpty()) {
                    liveCategoryDao.deleteTable()
                    liveCategoryDao.insertAll(*categories.toTypedArray())

                    return@withContext true
                }

                return@withContext false
            }
    }

    object MovieRESTParser {
        suspend fun parseMovie(movieDao: MovieDao, movies: List<Movie>): Boolean =
            withContext(Dispatchers.IO) {
                if (movies.isNotEmpty()) {
                    movieDao.deleteTable()
                    movieDao.insertAll(*movies.toTypedArray())

                    return@withContext true
                }

                return@withContext false
            }

        suspend fun parseMovieCategory(movieCategoryDao: MovieCategoryDao, categories: List<MovieCategory>): Boolean =
            withContext(Dispatchers.IO) {
                if (categories.isNotEmpty()) {
                    movieCategoryDao.deleteTable()
                    movieCategoryDao.insertAll(*categories.toTypedArray())

                    return@withContext true
                }

                return@withContext false
            }
    }

    object SeriesRESTParser {
        suspend fun parseSeries(seriesDao: SeriesDao, series: List<Series>): Boolean =
            withContext(Dispatchers.IO) {
                if (series.isNotEmpty()) {
                    seriesDao.deleteTable()
                    seriesDao.insertAll(*series.toTypedArray())

                    return@withContext true
                }

                return@withContext false
            }

        suspend fun parseSeriesCategory(seriesCategoryDao: SeriesCategoryDao, categories: List<SeriesCategory>): Boolean =
            withContext(Dispatchers.IO) {
                if (categories.isNotEmpty()) {
                    seriesCategoryDao.deleteTable()
                    seriesCategoryDao.insertAll(*categories.toTypedArray())

                    return@withContext true
                }

                return@withContext false
            }
    }
}
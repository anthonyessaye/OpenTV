package com.anthonyessaye.opentv.Activities

import android.content.Intent
import android.os.Bundle
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import com.anthonyessaye.opentv.Builders.XtreamBuilder
import com.anthonyessaye.opentv.Persistence.AppDatabase
import com.anthonyessaye.opentv.Persistence.DataParser
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.R
import com.anthonyessaye.opentv.REST.RESTHandler
import kotlinx.coroutines.launch

class CachingActivity : ComponentActivity() {
    private lateinit var textViewInformation: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_caching)

        textViewInformation = findViewById<TextView>(R.id.textViewInformation)
        textViewInformation.setText(getString(R.string.updating_live_streams))

        DatabaseManager().openDatabase(this) { db ->
            val user = db.userDao().getAll().first()
            val server = db.serverDao().getAll().first()

            val xtream = XtreamBuilder(user.username, user.password, server.buildURL())

            restLiveStream(db, xtream) { success ->
                if (success) {
                    runOnUiThread {
                        textViewInformation.setText(getString(R.string.updating_live_stream_categories))
                    }
                    restLiveStreamCategories(db, xtream) { success ->
                        if (success) {
                            runOnUiThread {
                                textViewInformation.setText(getString(R.string.updating_movies))
                            }

                            restMovie(db, xtream) { success ->
                                if (success) {
                                    runOnUiThread {
                                        textViewInformation.setText(getString(R.string.updates_movies_categories))
                                    }

                                    restMovieCategories(db, xtream) {  success ->
                                        if (success) {
                                            runOnUiThread {
                                                textViewInformation.setText(getString(R.string.updating_series))
                                            }

                                            restSeries(db, xtream) {  success ->
                                                if (success) {
                                                    runOnUiThread {
                                                        textViewInformation.setText(getString(R.string.updating_series_categories))
                                                    }

                                                    restSeriesCategories(db, xtream) {  success ->
                                                        runOnUiThread {
                                                            if (success) {
                                                                val intent = Intent(
                                                                    applicationContext,
                                                                    MainActivity::class.java
                                                                )
                                                                startActivity(intent)
                                                            } else
                                                                goToLogin()
                                                        }
                                                    }
                                                }

                                                else
                                                    goToLogin()
                                            }
                                        }

                                        else
                                            goToLogin()
                                    }
                                }

                                else
                                    goToLogin()
                            }
                        }

                        else
                            goToLogin()
                    }
                }

                else
                    goToLogin()
            }
        }
    }

    fun goToLogin() {
        runOnUiThread {
            Toast.makeText(
                applicationContext,
                getString(R.string.could_not_fetch_data),
                Toast.LENGTH_LONG
            ).show()
            val intent = Intent(applicationContext, LoginActivity::class.java)
            startActivity(intent)
        }
    }

    fun restLiveStream(db: AppDatabase, xtream: XtreamBuilder, completion: (success: Boolean) -> Unit) {
        RESTHandler.LiveStreamREST.getLiveStreamData(xtream) { liveStreams ->
            val liveStreamDao = db.liveStreamDao()
            lifecycleScope.launch { // coroutine on Main
                val insertLiveStreams = DataParser.LiveStreamRESTParser.parseLiveStream(liveStreamDao, liveStreams)
                completion(insertLiveStreams)
            }
        }
    }

    fun restLiveStreamCategories(db: AppDatabase, xtream: XtreamBuilder, completion: (success: Boolean) -> Unit) {
        RESTHandler.LiveStreamREST.getLiveStreamCategories(xtream) { liveStreamCategories ->
            val liveStreamCategoryDao = db.liveStreamCategoryDao()
            lifecycleScope.launch { // coroutine on Main
                val insertLiveStreamCategories = DataParser.LiveStreamRESTParser.parseLiveStreamCategory(liveStreamCategoryDao, liveStreamCategories)
                completion(insertLiveStreamCategories)
            }
        }
    }

    fun restMovie(db: AppDatabase, xtream: XtreamBuilder, completion: (success: Boolean) -> Unit) {
        RESTHandler.MovieREST.getMovieData(xtream) { movies ->
            val movieDao = db.movieDao()
            lifecycleScope.launch { // coroutine on Main
                val insertMovies = DataParser.MovieRESTParser.parseMovie(movieDao, movies)
                completion(insertMovies)
            }
        }
    }

    fun restMovieCategories(db: AppDatabase, xtream: XtreamBuilder, completion: (success: Boolean) -> Unit) {
        RESTHandler.MovieREST.getMovieCategories(xtream) { movieCategories ->
            val movieCategoryDao = db.movieCategoryDao()
            lifecycleScope.launch { // coroutine on Main
                val insertMovieCategories = DataParser.MovieRESTParser.parseMovieCategory(movieCategoryDao, movieCategories)
                completion(insertMovieCategories)
            }
        }
    }

    fun restSeries(db: AppDatabase, xtream: XtreamBuilder, completion: (success: Boolean) -> Unit) {
        RESTHandler.SeriesREST.getSeriesData(xtream) { series ->
            val seriesDao = db.seriesDao()
            lifecycleScope.launch { // coroutine on Main
                val insertSeries = DataParser.SeriesRESTParser.parseSeries(seriesDao, series)
                completion(insertSeries)
            }
        }
    }

    fun restSeriesCategories(db: AppDatabase, xtream: XtreamBuilder, completion: (success: Boolean) -> Unit) {
        RESTHandler.SeriesREST.getSeriesCategories(xtream) { seriesCategories ->
            val seriesCategoryDao = db.seriesCategoryDao()
            lifecycleScope.launch { // coroutine on Main
                val insertSeriesCategories = DataParser.SeriesRESTParser.parseSeriesCategory(seriesCategoryDao, seriesCategories)
                completion(insertSeriesCategories)
            }
        }
    }




}
package com.anthonyessaye.opentv.Activities.ListAllActivities

import android.content.Intent
import android.os.Bundle
import android.widget.EditText
import android.widget.ImageButton
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import app.moviebase.tmdb.model.TmdbSeason
import app.moviebase.tmdb.model.TmdbShowDetail
import com.anthonyessaye.opentv.Activities.DetailActivities.TvDetailActivity
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllSeriesActivity
import com.anthonyessaye.opentv.Adapters.EpisodeRecyclerViewAdapter
import com.anthonyessaye.opentv.Adapters.GridRecyclerViewAdapter
import com.anthonyessaye.opentv.Adapters.ListRecyclerViewAdapter
import com.anthonyessaye.opentv.Enums.RecyclerViewType
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Enums.ViewMode
import com.anthonyessaye.opentv.Helper
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Interfaces.RecyclerViewCallbackInterface
import com.anthonyessaye.opentv.Models.Series.SeriesDetails
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistory
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.R

class ListAllEpisodesActivity : ComponentActivity(), RecyclerViewCallbackInterface, PlayerInterface {
    private lateinit var recyclerViewCategoryList: RecyclerView
    private lateinit var recyclerViewLiveStreamList: RecyclerView
    private lateinit var editTextSearch: EditText
    private lateinit var imageBtnViewStyle: ImageButton

    lateinit var tvShow: SeriesDetails
    var viewMode: ViewMode = ViewMode.EPISODE
    var selectedKey: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activite_list_all_live_streams)

        recyclerViewCategoryList = findViewById<RecyclerView>(R.id.recyclerViewCategoryList)
        recyclerViewLiveStreamList = findViewById<RecyclerView>(R.id.recyclerViewLiveStreamList)
        editTextSearch = findViewById<EditText>(R.id.editTextSearch)
        imageBtnViewStyle = findViewById<ImageButton>(R.id.imageBtnViewStyle)

        tvShow = intent.getSerializableExtra(TvDetailActivity.SERIES) as SeriesDetails

        var dataSetPair = ArrayList<Pair<String, String>>()

        for (season in tvShow.episodes.keys) {
            dataSetPair.add(Pair(season, "Season ${season}"))
        }

        val customAdapter = ListRecyclerViewAdapter(dataSetPair.toTypedArray(), this, RecyclerViewType.LIST_CATEGORIES)

        runOnUiThread {
            recyclerViewCategoryList.layoutManager = LinearLayoutManager(this)
            recyclerViewCategoryList.adapter = customAdapter
        }

        loadEpisodesList(tvShow.episodes.keys.first())
    }

    fun loadEpisodesList(mapKey: String) {
        selectedKey = mapKey
        val availableStreamsAdapter = EpisodeRecyclerViewAdapter(tvShow.episodes[mapKey]!!, this,
            RecyclerViewType.LIST_SERIES)

        runOnUiThread {
            recyclerViewLiveStreamList.layoutManager = LinearLayoutManager(this)
            recyclerViewLiveStreamList.itemAnimator = null
            recyclerViewLiveStreamList.adapter = availableStreamsAdapter
        }
    }

    override fun processIntent(intent: Intent) {
        val recyclerViewType = intent.getStringExtra(Helper.KEY_RECYCLER_VIEW_TYPE)
        val id = intent.getStringExtra(Helper.KEY_ID)
        val longClick = intent.getBooleanExtra(Helper.LONG_PRESS, false)

        when(recyclerViewType) {
            RecyclerViewType.LIST_CATEGORIES.name -> {
                loadEpisodesList(id!!)
            }
            RecyclerViewType.LIST_MOVIES.name -> {}

            RecyclerViewType.LIST_SERIES.name -> {
                if(!longClick) {
                    DatabaseManager().openDatabase(this@ListAllEpisodesActivity) { db ->
                        val loggedInUser = db.userDao().getAll().first()
                        val serverInfo = db.serverDao().getAll().first()

                        val episode = tvShow.episodes[selectedKey]!!.first { it.id.toString() == id }

                        /*val movieHistory = MovieHistory(
                            mSelectedMovie.stream_id,
                            mSelectedMovie.name,
                            mSelectedMovie.container_extension,
                            (System.currentTimeMillis() / 1000).toString(),
                            mSelectedMovie.stream_icon.toString(),
                            "0"
                        )

                        db.movieHistoryDao().insertTop(50, movieHistory)*/

                        val streamURI = buildStreamURI(
                            serverInfo,
                            loggedInUser,
                            StreamType.SERIES,
                            episode.id.toInt(),
                            episode.container_extension
                        )

                        play(this@ListAllEpisodesActivity, streamURI)
                    }
                }

                else {
                    Toast.makeText(this@ListAllEpisodesActivity, "Not yet implemented", Toast.LENGTH_LONG).show()
                }
            }

        }
    }
}

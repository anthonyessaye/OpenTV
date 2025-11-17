package com.anthonyessaye.opentv.Activities.ListAllActivities

import android.content.Intent
import android.os.Bundle
import android.widget.EditText
import android.widget.ImageButton
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.core.content.ContentProviderCompat.requireContext
import androidx.lifecycle.lifecycleScope
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
import com.anthonyessaye.opentv.Persistence.History.SeriesHistory.SeriesHistory
import com.anthonyessaye.opentv.Persistence.History.SeriesHistory.SeriesHistoryDao
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ListAllEpisodesActivity : ComponentActivity(), RecyclerViewCallbackInterface, PlayerInterface {
    private lateinit var recyclerViewCategoryList: RecyclerView
    private lateinit var recyclerViewLiveStreamList: RecyclerView
    private lateinit var editTextSearch: EditText
    private lateinit var imageBtnViewStyle: ImageButton

    lateinit var tvShow: Series
    lateinit var seriesDetails: SeriesDetails
    lateinit var tvShowHistory: List<SeriesHistory>
    var viewMode: ViewMode = ViewMode.EPISODE
    var selectedKey: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activite_list_all_live_streams)

        recyclerViewCategoryList = findViewById<RecyclerView>(R.id.recyclerViewCategoryList)
        recyclerViewLiveStreamList = findViewById<RecyclerView>(R.id.recyclerViewLiveStreamList)
        editTextSearch = findViewById<EditText>(R.id.editTextSearch)
        imageBtnViewStyle = findViewById<ImageButton>(R.id.imageBtnViewStyle)

        tvShow = intent.getSerializableExtra(TvDetailActivity.SERIES) as Series
        seriesDetails = intent.getSerializableExtra(TvDetailActivity.SERIES_DETAIL) as SeriesDetails

        DatabaseManager().openDatabase(this) { db ->
            lifecycleScope.launch(Dispatchers.IO) {
                tvShowHistory = db.seriesHistoryDao().loadAllByIds(tvShow.series_id)

                withContext(Dispatchers.Main) {
                    var dataSetPair = ArrayList<Pair<String, String>>()

                    for (season in seriesDetails.episodes.keys) {
                        dataSetPair.add(Pair(season, "Season ${season}"))
                    }

                    val customAdapter = ListRecyclerViewAdapter(dataSetPair.toTypedArray(), emptyList(), this@ListAllEpisodesActivity, RecyclerViewType.LIST_CATEGORIES)

                    runOnUiThread {
                        recyclerViewCategoryList.layoutManager = LinearLayoutManager(this@ListAllEpisodesActivity)
                        recyclerViewCategoryList.adapter = customAdapter
                    }

                    loadEpisodesList(seriesDetails.episodes.keys.first(), tvShowHistory)
                }
            }
        }
    }

    fun loadEpisodesList(mapKey: String, tvShowHistory: List<SeriesHistory>) {
        selectedKey = mapKey
        var episodeIDToPositionPair = HashMap<Int, String>()

        for (history in tvShowHistory) {
            episodeIDToPositionPair.put(history.stream_id, history.position)
        }

        val availableStreamsAdapter = EpisodeRecyclerViewAdapter(seriesDetails.episodes[mapKey]!!, episodeIDToPositionPair, this,
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
                loadEpisodesList(id!!, tvShowHistory)
            }
            RecyclerViewType.LIST_MOVIES.name -> {}

            RecyclerViewType.LIST_SERIES.name -> {
                if(!longClick) {
                    DatabaseManager().openDatabase(this@ListAllEpisodesActivity) { db ->
                        val loggedInUser = db.userDao().getAll().first()
                        val serverInfo = db.serverDao().getAll().first()

                        val episode = seriesDetails.episodes[selectedKey]!!.first { it.id.toString() == id }
                        cache(this@ListAllEpisodesActivity, Pair(tvShow, episode), StreamType.SERIES)

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

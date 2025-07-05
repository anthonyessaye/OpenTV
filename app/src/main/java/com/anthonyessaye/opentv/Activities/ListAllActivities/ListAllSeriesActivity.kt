package com.anthonyessaye.opentv.Activities.ListAllActivities

import android.content.Intent
import android.os.Bundle
import android.widget.EditText
import android.widget.ImageButton
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.core.widget.doOnTextChanged
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.anthonyessaye.opentv.Activities.DetailActivities.MovieDetailActivity
import com.anthonyessaye.opentv.Activities.DetailActivities.TvDetailActivity
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllMoviesActivity
import com.anthonyessaye.opentv.Adapters.GridRecyclerViewAdapter
import com.anthonyessaye.opentv.Adapters.ListRecyclerViewAdapter
import com.anthonyessaye.opentv.Enums.RecyclerViewType
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Enums.ViewMode
import com.anthonyessaye.opentv.Helper
import com.anthonyessaye.opentv.Interfaces.FavoriteInterface
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Interfaces.RecyclerViewCallbackInterface
import com.anthonyessaye.opentv.Persistence.Categories.MovieCategory.MovieCategory
import com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory.SeriesCategory
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.Favorite.Favorite
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.R
import dev.anilbeesetti.nextplayer.feature.player.extensions.next
import kotlin.collections.forEach

class ListAllSeriesActivity: ComponentActivity(), RecyclerViewCallbackInterface, PlayerInterface, FavoriteInterface {
    private lateinit var recyclerViewCategoryList: RecyclerView
    private lateinit var recyclerViewLiveStreamList: RecyclerView
    private lateinit var editTextSearch: EditText
    private lateinit var imageBtnViewStyle: ImageButton

    private lateinit var allCategories: List<SeriesCategory>
    private var favorites: List<Favorite>? = null
    private lateinit var seriesInSelectedCategory: List<Series>

    var selectedCategoryIndexId = "-1"
    var viewMode: ViewMode = ViewMode.GRID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activite_list_all_live_streams)

        recyclerViewCategoryList = findViewById<RecyclerView>(R.id.recyclerViewCategoryList)
        recyclerViewLiveStreamList = findViewById<RecyclerView>(R.id.recyclerViewLiveStreamList)
        editTextSearch = findViewById<EditText>(R.id.editTextSearch)
        imageBtnViewStyle = findViewById<ImageButton>(R.id.imageBtnViewStyle)

        loadAllCategories()

        editTextSearch.doOnTextChanged { text, start, before, count ->

            var dataSetPair = ArrayList<Pair<String, String>>()

            if (!text.isNullOrEmpty()) {
                allCategories.filter { it.category_name.lowercase().contains(text.toString().lowercase()) }.forEach {
                    dataSetPair.add(Pair(it.category_id, it.category_name))
                }

                if (dataSetPair.count() == 1) {
                    loadSeriesList(dataSetPair.first().component1())
                }
            }

            else {
                allCategories.forEach {
                    dataSetPair.add(Pair(it.category_id, it.category_name))
                }
            }

            val customAdapter = ListRecyclerViewAdapter(dataSetPair.toTypedArray(),
                favorites?.map(Favorite::stream_id) ?: emptyList(),
                this,
                RecyclerViewType.LIST_CATEGORIES)

            recyclerViewCategoryList.layoutManager = LinearLayoutManager(this)
            recyclerViewCategoryList.adapter = customAdapter
        }

        imageBtnViewStyle.setOnClickListener {
            viewMode = viewMode.next()
            loadSeriesList(selectedCategoryIndexId)
        }
    }

    fun loadAllCategories() {
        DatabaseManager().openDatabase(this) { db ->
            allCategories = db.seriesCategoryDao().getAll().sortedBy( { it.category_name })
            favorites = db.favoriteDao().findByType(StreamType.SERIES.toString())?.sortedBy( { it.name })

            var dataSetPair = ArrayList<Pair<String, String>>()

            if (!favorites.isNullOrEmpty()) {
                dataSetPair.add(Pair("-1", getString(R.string.favorites)))
            }
            allCategories.forEach {
                dataSetPair.add(Pair(it.category_id, it.category_name))
            }

            val customAdapter = ListRecyclerViewAdapter(dataSetPair.toTypedArray(),
                favorites?.map(Favorite::stream_id) ?: emptyList(),
                this,
                RecyclerViewType.LIST_CATEGORIES)

            runOnUiThread {
                recyclerViewCategoryList.layoutManager = LinearLayoutManager(this)
                recyclerViewCategoryList.adapter = customAdapter
                selectedCategoryIndexId = allCategories.first().category_id
            }

            if (favorites.isNullOrEmpty())
                loadSeriesList(allCategories.first().category_id)

            else
                loadFavorites()
        }
    }

    fun loadSeriesList(id: String) {
        selectedCategoryIndexId = id
        DatabaseManager().openDatabase(this) { db ->
            var dataSet = ArrayList<Pair<String, String>>()
            var images = ArrayList<String>()

            seriesInSelectedCategory = db.seriesDao().findByCategoryId(id).sortedBy {it.name}

            seriesInSelectedCategory.forEach {
                dataSet.add(Pair(it.series_id.toString(), it.name))
                images.add(it.cover.toString())
            }

            when(viewMode) {
                ViewMode.LIST -> {
                    val availableStreamsAdapter = ListRecyclerViewAdapter(dataSet.toTypedArray(),
                        favorites?.map(Favorite::stream_id) ?: emptyList(),
                        this,
                        RecyclerViewType.LIST_SERIES)

                    runOnUiThread {
                        recyclerViewLiveStreamList.layoutManager = LinearLayoutManager(this)
                        recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                    }
                }

                ViewMode.GRID -> {
                    val availableStreamsAdapter = GridRecyclerViewAdapter(dataSet.toTypedArray(),
                        images.toTypedArray(),
                        favorites?.map(Favorite::stream_id) ?: emptyList(),
                        this,
                        RecyclerViewType.LIST_SERIES)

                    runOnUiThread {
                        recyclerViewLiveStreamList.layoutManager =  GridLayoutManager(this,5)
                        recyclerViewLiveStreamList.itemAnimator = null
                        recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                    }
                }

                ViewMode.EPISODE -> {
                    runOnUiThread {
                        imageBtnViewStyle.performClick()
                    }
                }
            }
        }
    }

    fun loadFavorites() {
        selectedCategoryIndexId = "-1"
        DatabaseManager().openDatabase(this) { db ->
            var dataSet = ArrayList<Pair<String, String>>()
            var images = ArrayList<String>()

            favorites!!.forEach {
                dataSet.add(Pair(it.stream_id.toString(), it.name))
                images.add(it.stream_icon.toString())
            }

            when(viewMode) {
                ViewMode.LIST -> {
                    val availableStreamsAdapter = ListRecyclerViewAdapter(dataSet.toTypedArray(),
                        favorites?.map(Favorite::stream_id) ?: emptyList(),
                        this,
                        RecyclerViewType.LIST_SERIES)

                    runOnUiThread {
                        recyclerViewLiveStreamList.layoutManager = LinearLayoutManager(this)
                        recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                    }
                }

                ViewMode.GRID -> {
                    val availableStreamsAdapter = GridRecyclerViewAdapter(dataSet.toTypedArray(),
                        images.toTypedArray(),
                        favorites?.map(Favorite::stream_id) ?: emptyList(),
                        this,
                        RecyclerViewType.LIST_SERIES)

                    runOnUiThread {
                        recyclerViewLiveStreamList.layoutManager =  GridLayoutManager(this,5)
                        recyclerViewLiveStreamList.itemAnimator = null
                        recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                    }
                }

                ViewMode.EPISODE ->  {
                    runOnUiThread {
                        imageBtnViewStyle.performClick()
                    }
                }
            }
        }
    }


    override fun processIntent(intent: Intent) {
        val recyclerViewType = intent.getStringExtra(Helper.KEY_RECYCLER_VIEW_TYPE)
        val id = intent.getStringExtra(Helper.KEY_ID)
        val longClick = intent.getBooleanExtra(Helper.LONG_PRESS, false)

        when(recyclerViewType) {
            RecyclerViewType.LIST_CATEGORIES.name -> {
                selectedCategoryIndexId = id!!


                if(selectedCategoryIndexId != "-1")
                    loadSeriesList(selectedCategoryIndexId)

                else
                    loadFavorites()
            }
            RecyclerViewType.LIST_MOVIES.name -> {}

            RecyclerViewType.LIST_SERIES.name -> {
                if(!longClick) {
                    DatabaseManager().openDatabase(this@ListAllSeriesActivity) { db ->
                        val series = db.seriesDao().findById(id!!)
                        val intent = Intent(this@ListAllSeriesActivity, TvDetailActivity::class.java)
                        intent.putExtra(TvDetailActivity.SERIES, series)

                        startActivity(intent)
                    }
                }

                else {
                    DatabaseManager().openDatabase(this@ListAllSeriesActivity) { db ->
                        val series = db.seriesDao().findById(id.toString())

                        val favorite: Favorite = Favorite(series.series_id,
                            series.name,
                            series.cover,
                            StreamType.SERIES.toString())

                        addOrDeleteFavorite(this@ListAllSeriesActivity, favorite)
                        loadAllCategories()
                    }
                }
            }

        }
    }
}
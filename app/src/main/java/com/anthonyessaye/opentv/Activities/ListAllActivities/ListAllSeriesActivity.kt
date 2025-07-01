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
import com.anthonyessaye.opentv.Enums.ViewMode
import com.anthonyessaye.opentv.Helper
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Interfaces.RecyclerViewCallbackInterface
import com.anthonyessaye.opentv.Persistence.Categories.MovieCategory.MovieCategory
import com.anthonyessaye.opentv.Persistence.Categories.SeriesCategory.SeriesCategory
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.R
import dev.anilbeesetti.nextplayer.feature.player.extensions.next
import kotlin.collections.forEach

class ListAllSeriesActivity: ComponentActivity(), RecyclerViewCallbackInterface, PlayerInterface {
    private lateinit var recyclerViewCategoryList: RecyclerView
    private lateinit var recyclerViewLiveStreamList: RecyclerView
    private lateinit var editTextSearch: EditText
    private lateinit var imageBtnViewStyle: ImageButton

    private lateinit var allCategories: List<SeriesCategory>
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

            val customAdapter = ListRecyclerViewAdapter(dataSetPair.toTypedArray(), this, RecyclerViewType.LIST_CATEGORIES)

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

            var dataSetPair = ArrayList<Pair<String, String>>()

            allCategories.forEach {
                dataSetPair.add(Pair(it.category_id, it.category_name))
            }

            val customAdapter = ListRecyclerViewAdapter(dataSetPair.toTypedArray(), this, RecyclerViewType.LIST_CATEGORIES)

            runOnUiThread {
                recyclerViewCategoryList.layoutManager = LinearLayoutManager(this)
                recyclerViewCategoryList.adapter = customAdapter
                selectedCategoryIndexId = allCategories.first().category_id
            }

            loadSeriesList(allCategories.first().category_id)
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
                    val availableStreamsAdapter = ListRecyclerViewAdapter(dataSet.toTypedArray(), this,
                        RecyclerViewType.LIST_SERIES)

                    runOnUiThread {
                        recyclerViewLiveStreamList.layoutManager = LinearLayoutManager(this)
                        recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                    }
                }

                ViewMode.GRID -> {
                    val availableStreamsAdapter = GridRecyclerViewAdapter(dataSet.toTypedArray(), images.toTypedArray(), this,
                        RecyclerViewType.LIST_SERIES)

                    runOnUiThread {
                        recyclerViewLiveStreamList.layoutManager =  GridLayoutManager(this,5)
                        recyclerViewLiveStreamList.itemAnimator = null
                        recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                    }
                }

                ViewMode.EPISODE -> {

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
                loadSeriesList(selectedCategoryIndexId)
            }
            RecyclerViewType.LIST_MOVIES.name -> {}

            RecyclerViewType.LIST_SERIES.name -> {
                if(!longClick) {
                    DatabaseManager().openDatabase(this@ListAllSeriesActivity) { db ->
                        val series = seriesInSelectedCategory.first { it.series_id.toString() == id }
                        val intent = Intent(this@ListAllSeriesActivity, TvDetailActivity::class.java)
                        intent.putExtra(TvDetailActivity.SERIES, series)

                        startActivity(intent)
                    }
                }

                else {
                    Toast.makeText(this@ListAllSeriesActivity, "Not yet implemented", Toast.LENGTH_LONG).show()
                }
            }

        }
    }
}
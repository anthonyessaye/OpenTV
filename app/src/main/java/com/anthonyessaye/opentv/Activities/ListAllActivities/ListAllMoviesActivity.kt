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
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllLiveStreamsActivity
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
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.Favorite.Favorite
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.R
import dev.anilbeesetti.nextplayer.feature.player.extensions.next

class ListAllMoviesActivity : ComponentActivity(), RecyclerViewCallbackInterface, PlayerInterface, FavoriteInterface {
    private lateinit var recyclerViewCategoryList: RecyclerView
    private lateinit var recyclerViewLiveStreamList: RecyclerView
    private lateinit var editTextSearch: EditText
    private lateinit var imageBtnViewStyle: ImageButton

    private lateinit var allCategories: List<MovieCategory>
    private var favorites: List<Favorite>? = null
    private lateinit var moviesInSelectedCategory: List<Movie>

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
                    loadMoviesList(dataSetPair.first().component1())
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
            loadMoviesList(selectedCategoryIndexId)
        }
    }

    fun loadAllCategories() {
        DatabaseManager().openDatabase(this) { db ->
            allCategories = db.movieCategoryDao().getAll().sortedBy( { it.category_name })
            favorites = db.favoriteDao().findByType(StreamType.MOVIE.toString())?.sortedBy( { it.name })

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
                loadMoviesList(allCategories.first().category_id)

            else
                loadFavorites()
        }
    }

    fun loadMoviesList(id: String) {
        selectedCategoryIndexId = id
        DatabaseManager().openDatabase(this) { db ->
            var dataSet = ArrayList<Pair<String, String>>()
            var images = ArrayList<String>()

            moviesInSelectedCategory = db.movieDao().findByCategoryId(id).sortedBy {it.name}

            moviesInSelectedCategory.forEach {
                dataSet.add(Pair(it.stream_id.toString(), it.name))
                images.add(it.stream_icon.toString())
            }

            when(viewMode) {
                ViewMode.LIST -> {
                    val availableStreamsAdapter = ListRecyclerViewAdapter(dataSet.toTypedArray(),
                        favorites?.map(Favorite::stream_id) ?: emptyList(),
                        this,
                        RecyclerViewType.LIST_MOVIES)

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
                        RecyclerViewType.LIST_MOVIES)

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
                        RecyclerViewType.LIST_MOVIES)

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
                        RecyclerViewType.LIST_MOVIES)

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
            RecyclerViewType.LIST_MOVIES.name -> {
                if(!longClick) {
                    DatabaseManager().openDatabase(this@ListAllMoviesActivity) { db ->
                        val movie = db.movieDao().findById(id!!)
                        val intent = Intent(this@ListAllMoviesActivity, MovieDetailActivity::class.java)
                        intent.putExtra(MovieDetailActivity.MOVIE, movie)

                        startActivity(intent)
                    }
                }

                else {
                    DatabaseManager().openDatabase(this@ListAllMoviesActivity) { db ->
                        val movie = db.movieDao().findById(id.toString())

                        val favorite: Favorite = Favorite(movie.stream_id,
                            movie.name,
                            movie.stream_icon,
                            StreamType.MOVIE.toString())

                        addOrDeleteFavorite(this@ListAllMoviesActivity, favorite)
                        loadAllCategories()
                    }
                }

            }

            RecyclerViewType.LIST_CATEGORIES.name -> {
                selectedCategoryIndexId = id!!

                if(selectedCategoryIndexId != "-1")
                    loadMoviesList(selectedCategoryIndexId)

                else
                    loadFavorites()
            }

            RecyclerViewType.LIST_SERIES.name -> {}

        }
    }
}
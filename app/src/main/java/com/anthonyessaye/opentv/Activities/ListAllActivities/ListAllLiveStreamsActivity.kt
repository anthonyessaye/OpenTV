package com.anthonyessaye.opentv.Activities.ListAllActivities

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.EditText
import android.widget.ImageButton
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.core.net.toUri
import androidx.core.widget.doOnTextChanged
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.anthonyessaye.opentv.Adapters.GridRecyclerViewAdapter
import com.anthonyessaye.opentv.Adapters.ListRecyclerViewAdapter
import com.anthonyessaye.opentv.Enums.RecyclerViewType
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Enums.ViewMode
import com.anthonyessaye.opentv.Helper
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Interfaces.RecyclerViewCallbackInterface
import com.anthonyessaye.opentv.Persistence.Categories.LiveCategory.LiveCategory
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream
import com.anthonyessaye.opentv.R
import dev.anilbeesetti.nextplayer.feature.player.extensions.next
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ListAllLiveStreamsActivity : ComponentActivity(), RecyclerViewCallbackInterface, PlayerInterface {
    private lateinit var recyclerViewCategoryList: RecyclerView
    private lateinit var recyclerViewLiveStreamList: RecyclerView
    private lateinit var editTextSearch: EditText
    private lateinit var imageBtnViewStyle: ImageButton

    private lateinit var allCategories: List<LiveCategory>
    private lateinit var streamsInSelectedCategory: List<LiveStream>

    var selectedCategoryIndexId = "-1"
    var viewMode: ViewMode = ViewMode.LIST

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
                    loadStreamsList(dataSetPair.first().component1())
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
            loadStreamsList(selectedCategoryIndexId)
        }
    }

    fun loadAllCategories() {
        DatabaseManager().openDatabase(this) { db ->
            allCategories = db.liveStreamCategoryDao().getAll().sortedBy( { it.category_name })

            var dataSetPair = ArrayList<Pair<String, String>>()

            allCategories.forEach {
                dataSetPair.add(Pair(it.category_id, it.category_name))
            }

            val customAdapter = ListRecyclerViewAdapter(dataSetPair.toTypedArray(), this, RecyclerViewType.LIST_CATEGORIES)

            runOnUiThread {
                recyclerViewCategoryList.layoutManager = LinearLayoutManager(this)
                recyclerViewCategoryList.adapter = customAdapter

                selectedCategoryIndexId = allCategories.first().category_id
                loadStreamsList(allCategories.first().category_id)
            }
        }
    }

    fun loadStreamsList(id: String) {
        selectedCategoryIndexId = id
        DatabaseManager().openDatabase(this) { db ->
            var dataSet = ArrayList<Pair<String, String>>()
            var images = ArrayList<String>()

            streamsInSelectedCategory = db.liveStreamDao().findByCategoryId(id).sortedBy {it.name}

            streamsInSelectedCategory.forEach {
                dataSet.add(Pair(it.stream_id.toString(), it.name))
                images.add(it.stream_icon.toString())
            }

            when(viewMode) {
                ViewMode.LIST -> {
                    val availableStreamsAdapter = ListRecyclerViewAdapter(dataSet.toTypedArray(), this,
                        RecyclerViewType.LIST_LIVE_STREAMS)

                        runOnUiThread {
                            recyclerViewLiveStreamList.layoutManager = LinearLayoutManager(this)
                            recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                        }
                }

                ViewMode.GRID -> {
                    val availableStreamsAdapter = GridRecyclerViewAdapter(dataSet.toTypedArray(), images.toTypedArray(), this,
                            RecyclerViewType.LIST_LIVE_STREAMS)

                    runOnUiThread {
                        recyclerViewLiveStreamList.layoutManager =  GridLayoutManager(this,5)
                        recyclerViewLiveStreamList.itemAnimator = null
                        recyclerViewLiveStreamList.adapter = availableStreamsAdapter
                    }
                }

                ViewMode.EPISODE ->  { }
            }
        }
    }

    override fun processIntent(intent: Intent) {
        val recyclerViewType = intent.getStringExtra(Helper.KEY_RECYCLER_VIEW_TYPE)
        val id = intent.getStringExtra(Helper.KEY_ID)
        val longClick: Boolean = intent.getBooleanExtra(Helper.LONG_PRESS, false)

        when(recyclerViewType) {
            RecyclerViewType.LIST_LIVE_STREAMS.name -> {
                if(!longClick) {
                    DatabaseManager().openDatabase(this@ListAllLiveStreamsActivity) { db ->
                        val liveStream =
                            streamsInSelectedCategory.first { it.stream_id.toString() == id }
                        val serverInfo = db.serverDao().getAll().first()
                        val loggedInUser = db.userDao().getAll().first()

                        // Write history to disk
                        lifecycleScope.launch(Dispatchers.IO) {
                            val liveHistory = LiveHistory(
                                liveStream.stream_id,
                                liveStream.name,
                                (System.currentTimeMillis() / 1000).toString(),
                                liveStream.stream_icon
                            )

                            db.liveHistoryDao().insertTop(10, liveHistory)
                        }

                        val streamURI = buildStreamURI(
                            serverInfo,
                            loggedInUser,
                            StreamType.LIVE,
                            id!!.toInt(),
                            "ts"
                        )
                        play(this@ListAllLiveStreamsActivity, streamURI)
                    }
                }

                else {
                    Toast.makeText(this@ListAllLiveStreamsActivity, "Not yet implemented", Toast.LENGTH_LONG).show()
                }

            }

            RecyclerViewType.LIST_CATEGORIES.name -> {
                selectedCategoryIndexId = id!!
                loadStreamsList(selectedCategoryIndexId)
            }
            RecyclerViewType.LIST_MOVIES.name, RecyclerViewType.LIST_SERIES.name -> {}

        }
    }
}
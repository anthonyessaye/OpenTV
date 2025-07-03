package com.anthonyessaye.opentv.Fragments

import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.leanback.app.BackgroundManager
import androidx.leanback.app.BrowseSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.OnItemViewClickedListener
import androidx.leanback.widget.OnItemViewSelectedListener
import androidx.leanback.widget.Presenter
import androidx.leanback.widget.Row
import androidx.leanback.widget.RowPresenter
import androidx.lifecycle.lifecycleScope
import com.anthonyessaye.opentv.Activities.CachingActivity
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllLiveStreamsActivity
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllMoviesActivity
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllSeriesActivity
import com.anthonyessaye.opentv.Activities.SearchActivity
import com.anthonyessaye.opentv.Presenters.CardPresenter
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistory
import com.anthonyessaye.opentv.Persistence.History.SeriesHistory.SeriesHistory
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.Persistence.User.User
import com.anthonyessaye.opentv.R
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.SimpleTarget
import com.bumptech.glide.request.transition.Transition
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Timer
import java.util.TimerTask

/**
 * Loads a grid of cards with movies to browse.
 */
class MainFragment : BrowseSupportFragment(), PlayerInterface {

    private val mHandler = Handler(Looper.myLooper()!!)
    private lateinit var mBackgroundManager: BackgroundManager
    private var mDefaultBackground: Drawable? = null
    private lateinit var mMetrics: DisplayMetrics
    private var mBackgroundTimer: Timer? = null
    private var mBackgroundUri: String? = null

    // ------------------------------------------------------
    private var namesToDataMap: HashMap<String, Any> = HashMap()
    private lateinit var sidebarItems: ArrayList<String>
    private lateinit var loggedInUser: User
    private var liveStreamHistory : List<LiveHistory> = emptyList()
    private var moviesHistory: List<MovieHistory> = emptyList()
    private var seriesHistory : List<SeriesHistory> = emptyList()


    override fun onActivityCreated(savedInstanceState: Bundle?) {
        Log.i(TAG, "onCreate")
        super.onActivityCreated(savedInstanceState)
        prepareBackgroundManager()
        setupEventListeners()
    }

    override fun onResume() {
        super.onResume()

        updateData()
        setupUIElements()
        loadRows()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy: " + mBackgroundTimer?.toString())
        mBackgroundTimer?.cancel()
    }

    private fun updateData() {
        // Get cached data
        DatabaseManager().openDatabase(requireContext()) { db ->
            loggedInUser = db.userDao().getAll().first()
            liveStreamHistory = db.liveHistoryDao().getAll().sortedBy { it.last_watched }.reversed()
            moviesHistory = db.movieHistoryDao().getAll().sortedBy { it.last_watched }.reversed()
            seriesHistory = db.seriesHistoryDao().getAll().sortedBy { it.last_watched }.reversed()

            namesToDataMap.put(getString(R.string.live_streams), liveStreamHistory)
            namesToDataMap.put(getString(R.string.movies), moviesHistory)
            namesToDataMap.put(getString(R.string.series), seriesHistory)
        }
    }

    private fun prepareBackgroundManager() {
        mBackgroundManager = BackgroundManager.getInstance(activity)
        mBackgroundManager.attach(activity!!.window)
        mDefaultBackground = ContextCompat.getDrawable(context!!, R.drawable.default_background)
        mMetrics = DisplayMetrics()
        activity!!.windowManager.defaultDisplay.getMetrics(mMetrics)
    }

    private fun setupUIElements() {
        title = getString(R.string.logged_user) + " ${loggedInUser.username}"
        headersState = HEADERS_ENABLED
        isHeadersTransitionOnBackEnabled = true

        brandColor = ContextCompat.getColor(context!!, R.color.minor_color_blue)
        searchAffordanceColor = ContextCompat.getColor(context!!, R.color.major_color_blue)
    }

    private fun loadRows() {
        val list = namesToDataMap.keys

        val rowsAdapter = ArrayObjectAdapter(ListRowPresenter())
        val cardPresenter = CardPresenter()

        for (item in list) {
            val listRowAdapter = ArrayObjectAdapter(cardPresenter)
            listRowAdapter.add(item)

            if (item == getString(R.string.live_streams)) {
                val data = namesToDataMap[item] as List<LiveHistory>
                for (dItem in data) {
                    listRowAdapter.add(dItem)
                }
            }

            else if (item == getString(R.string.movies)) {
                val data = namesToDataMap[item] as List<MovieHistory>
                for (dItem in data) {
                    listRowAdapter.add(dItem)
                }
            }

            else if (item == getString(R.string.series)) {
                val data = namesToDataMap[item] as List<SeriesHistory>
                for (dItem in data) {
                    listRowAdapter.add(dItem)
                }
            }

            val header = HeaderItem(item)
            rowsAdapter.add(ListRow(header, listRowAdapter))
        }

        val gridHeader = HeaderItem(NUM_ROWS.toLong(), "Settings")

        val mGridPresenter = GridItemPresenter()
        val gridRowAdapter = ArrayObjectAdapter(mGridPresenter)
        gridRowAdapter.add(getString(R.string.refresh_data)) 
        rowsAdapter.add(ListRow(gridHeader, gridRowAdapter))

        adapter = rowsAdapter
    }

    private fun setupEventListeners() {
        setOnSearchClickedListener {
            val intent = Intent(requireContext(), SearchActivity::class.java)
            startActivity(intent)
        }

        onItemViewClickedListener = ItemViewClickedListener()
        onItemViewSelectedListener = ItemViewSelectedListener()
    }

    private inner class ItemViewClickedListener : OnItemViewClickedListener {
        override fun onItemClicked(
            itemViewHolder: Presenter.ViewHolder,
            item: Any,
            rowViewHolder: RowPresenter.ViewHolder,
            row: Row
        ) {


            if (item is LiveHistory) {
                DatabaseManager().openDatabase(requireContext()) { db ->
                    val loggedInUser = db.userDao().getAll().first()
                    val server = db.serverDao().getAll().first()
                    val streamType = StreamType.LIVE

                    // update history on disk
                    lifecycleScope.launch(Dispatchers.IO) {
                        db.liveHistoryDao().update((System.currentTimeMillis()/1000).toString(), item.stream_id)
                    }

                    val streamURI = buildStreamURI(server, loggedInUser, streamType, item.stream_id, "ts")
                    play(requireContext(), streamURI)
                }
            }

            else if (item is MovieHistory) {
                DatabaseManager().openDatabase(requireContext()) { db ->
                    val loggedInUser = db.userDao().getAll().first()
                    val server = db.serverDao().getAll().first()
                    val streamType = StreamType.MOVIE

                    // update history on disk
                    lifecycleScope.launch(Dispatchers.IO) {
                        db.movieHistoryDao().updateLastWatched((System.currentTimeMillis()/1000).toString(), item.stream_id)
                    }

                    val streamURI = buildStreamURI(server, loggedInUser, streamType, item.stream_id, item.container_extension)
                    play(requireContext(), streamURI)
                }
            }

            else if (item is String) {
                    if (item.contains(getString(R.string.live_streams))) {
                        val intent = Intent(context!!, ListAllLiveStreamsActivity::class.java)
                        startActivity(intent)
                    }

                    else if (item.contains(getString(R.string.movies))) {
                        val intent = Intent(context!!, ListAllMoviesActivity::class.java)
                        startActivity(intent)
                    }

                    else if (item.contains(getString(R.string.series))) {
                        val intent = Intent(context!!, ListAllSeriesActivity::class.java)
                        startActivity(intent)
                    }

                    else if (item.contains(getString(R.string.refresh_data))) {
                        val intent = Intent(context!!, CachingActivity::class.java)
                        startActivity(intent)
                    }

                    else {
                        Toast.makeText(context!!, "Not Implemented Yet", Toast.LENGTH_LONG).show()
                    }

            }
        }
    }

    private inner class ItemViewSelectedListener : OnItemViewSelectedListener {
        override fun onItemSelected(
            itemViewHolder: Presenter.ViewHolder?, item: Any?,
            rowViewHolder: RowPresenter.ViewHolder, row: Row
        ) {
            /*if (item is Movie) {
                mBackgroundUri = item.backgroundImageUrl
                startBackgroundTimer()
            }*/
        }
    }

    private fun updateBackground(uri: String?) {
        val width = mMetrics.widthPixels
        val height = mMetrics.heightPixels
        Glide.with(context!!)
            .load(uri)
            .centerCrop()
            .error(mDefaultBackground)
            .into<SimpleTarget<Drawable>>(
                object : SimpleTarget<Drawable>(width, height) {
                    override fun onResourceReady(
                        drawable: Drawable,
                        transition: Transition<in Drawable>?
                    ) {
                        mBackgroundManager.drawable = drawable
                    }
                })
        mBackgroundTimer?.cancel()
    }

    private fun startBackgroundTimer() {
        mBackgroundTimer?.cancel()
        mBackgroundTimer = Timer()
        mBackgroundTimer?.schedule(UpdateBackgroundTask(), BACKGROUND_UPDATE_DELAY.toLong())
    }

    private inner class UpdateBackgroundTask : TimerTask() {

        override fun run() {
            mHandler.post { updateBackground(mBackgroundUri) }
        }
    }

    private inner class GridItemPresenter : Presenter() {
        override fun onCreateViewHolder(parent: ViewGroup): ViewHolder {
            val view = TextView(parent.context)
            view.layoutParams = ViewGroup.LayoutParams(GRID_ITEM_WIDTH, GRID_ITEM_HEIGHT)
            view.isFocusable = true
            view.isFocusableInTouchMode = true
            view.setBackgroundColor(ContextCompat.getColor(context!!, R.color.default_background))
            view.setTextColor(Color.WHITE)
            view.gravity = Gravity.CENTER
            return ViewHolder(view)
        }

        override fun onBindViewHolder(viewHolder: ViewHolder, item: Any?) {
            (viewHolder.view as TextView).text = item as String
        }

        override fun onUnbindViewHolder(viewHolder: ViewHolder) {}
    }

    companion object {
        private val TAG = "MainFragment"

        private val BACKGROUND_UPDATE_DELAY = 300
        private val GRID_ITEM_WIDTH = 200
        private val GRID_ITEM_HEIGHT = 200
        private val NUM_ROWS = 6
        private val NUM_COLS = 15
    }
}
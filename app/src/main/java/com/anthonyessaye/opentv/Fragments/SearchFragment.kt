package com.anthonyessaye.opentv.Fragments

import android.content.Intent
import android.os.Bundle
import androidx.core.app.ActivityOptionsCompat
import androidx.leanback.app.SearchSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.ClassPresenterSelector
import androidx.leanback.widget.DetailsOverviewRow
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.ObjectAdapter
import androidx.leanback.widget.OnItemViewClickedListener
import androidx.leanback.widget.Presenter
import androidx.leanback.widget.Row
import androidx.leanback.widget.RowPresenter
import androidx.lifecycle.lifecycleScope
import com.anthonyessaye.opentv.Activities.DetailActivities.MovieDetailActivity
import com.anthonyessaye.opentv.Activities.DetailActivities.TvDetailActivity
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllLiveStreamsActivity
import com.anthonyessaye.opentv.Adapters.MovieCardView
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Fragments.MovieDetailFragment.Companion.TRANSITION_NAME
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Models.MovieResponse
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.Presenters.SearchLiveStreamPresenter
import com.anthonyessaye.opentv.Presenters.SearchMoviePresenter
import com.anthonyessaye.opentv.Presenters.SearchSeriesPresenter
import com.anthonyessaye.opentv.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class SearchFragment : SearchSupportFragment(), SearchSupportFragment.SearchResultProvider,
    OnItemViewClickedListener, PlayerInterface {
    var arrayAdapter: ArrayObjectAdapter? = null
    var arrayObjectAdapter: ArrayObjectAdapter? = null

    var matchingMovies: ListRow? = null
    var matchingSeries: ListRow? = null
    var matchingLiveStream: ListRow? = null
    var matchingLiveStreamAdapter: ArrayObjectAdapter = ArrayObjectAdapter(SearchLiveStreamPresenter())
    var matchingMovieAdapter: ArrayObjectAdapter = ArrayObjectAdapter(SearchMoviePresenter())
    var matchingSeriesAdapter: ArrayObjectAdapter = ArrayObjectAdapter(SearchSeriesPresenter())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        arrayAdapter = ArrayObjectAdapter(ListRowPresenter())

        val selector: ClassPresenterSelector = ClassPresenterSelector()
        selector.addClassPresenter(ListRow::class.java, ListRowPresenter())
        arrayObjectAdapter = ArrayObjectAdapter(selector)

        setSearchResultProvider(this)
        setupSearchRow()
    }


    override fun getResultsAdapter(): ObjectAdapter {
        return arrayAdapter!!
    }

    override fun onQueryTextChange(query: String?): Boolean {
        performSearch()

        if (query == null || query.trim { it <= ' ' }.isEmpty()) {
            performSearch()
            return true
        }

        DatabaseManager().openDatabase(requireContext()) { db ->
            val series: List<Series> = db.seriesDao().findByLikeName(query, 10)
            val movies: List<Movie> = db.movieDao().findByLikeName(query, 10)
            val liveStreams: List<LiveStream> = db.liveStreamDao().findByLikeName(query, 10)

            requireActivity().runOnUiThread {
                arrayAdapter!!.clear()
                matchingLiveStreamAdapter.clear()
                matchingMovieAdapter.clear()
                matchingSeriesAdapter.clear()

                if (!movies.isEmpty()) {
                    matchingMovieAdapter.addAll(0, movies)
                    matchingMovies =
                        ListRow(HeaderItem(1, getString(R.string.movies)), matchingMovieAdapter)
                    arrayAdapter!!.add(matchingMovies!!)
                }

                if (!liveStreams.isEmpty()) {
                    matchingLiveStreamAdapter.addAll(0, liveStreams)
                    matchingLiveStream =
                        ListRow(
                            HeaderItem(0, getString(R.string.live_streams)),
                            matchingLiveStreamAdapter
                        )
                    arrayAdapter!!.add(matchingLiveStream!!)
                }

                if (!series.isEmpty()) {
                    matchingSeriesAdapter.addAll(0, series)
                    matchingSeries =
                        ListRow(HeaderItem(2, getString(R.string.series)), matchingSeriesAdapter)
                    arrayAdapter!!.add(matchingSeries!!)
                }
            }
        }

        return true
    }

    override fun onQueryTextSubmit(query: String?): Boolean {
        return onQueryTextChange(query)
    }

    private fun setupSearchRow() {
        arrayAdapter!!.add(ListRow(HeaderItem(0, "" + ""), arrayObjectAdapter))
        setOnItemViewClickedListener(this)
    }


    private fun bindSearch(responseObj: MovieResponse) {
        arrayObjectAdapter!!.clear()
        arrayObjectAdapter!!.addAll(0, responseObj.getResults())
    }

    private fun performSearch() {
        requireActivity().runOnUiThread {
            arrayObjectAdapter!!.clear()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        setSearchQuery(data, true)
    }


    override fun onItemClicked(
        viewHolder: Presenter.ViewHolder?,
        item: Any?,
        itemViewHolder: RowPresenter.ViewHolder,
        row: Row?
    ) {
        if (item is Movie) {
            val movie = item
            val intent = Intent(getActivity(), MovieDetailActivity::class.java)
            intent.putExtra(Movie::class.java.getSimpleName(), movie)

            if (itemViewHolder.view is MovieCardView) {
                val bundle = ActivityOptionsCompat.makeSceneTransitionAnimation(
                    requireActivity(),
                    (itemViewHolder.view as MovieCardView).getPosterIV(),
                    TRANSITION_NAME
                ).toBundle()
                requireActivity().startActivity(intent, bundle)
            } else {
                startActivity(intent)
            }
        }

        else if (item is LiveStream) {
            DatabaseManager().openDatabase(requireContext()) { db ->
                val serverInfo = db.serverDao().getAll().first()
                val loggedInUser = db.userDao().getAll().first()

                cache(requireContext(), item.stream_id, item.name, item.stream_icon, StreamType.LIVE)

                val streamURI = buildStreamURI(
                    serverInfo,
                    loggedInUser,
                    StreamType.LIVE,
                    item.stream_id,
                    "ts"
                )
                play(requireContext(), streamURI)
            }
        }

        else if (item is Series) {
            val intent = Intent(getActivity(), TvDetailActivity::class.java)
            intent.putExtra(TvDetailActivity.SERIES, item)
            startActivity(intent)
        }
    }

    companion object {
        fun newInstance(): SearchFragment {
            val args = Bundle()
            val fragment = SearchFragment()
            fragment.setArguments(args)
            return fragment
        }
    }
}

package com.anthonyessaye.opentv.Fragments

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.view.View
import androidx.core.app.ActivityOptionsCompat
import androidx.core.net.toUri
import androidx.leanback.app.DetailsSupportFragment
import androidx.leanback.widget.Action
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.ClassPresenterSelector
import androidx.leanback.widget.DetailsOverviewLogoPresenter
import androidx.leanback.widget.DetailsOverviewRow
import androidx.leanback.widget.FullWidthDetailsOverviewSharedElementHelper
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.OnActionClickedListener
import androidx.leanback.widget.OnItemViewClickedListener
import androidx.leanback.widget.Presenter
import androidx.leanback.widget.Row
import androidx.leanback.widget.RowPresenter
import androidx.leanback.widget.SparseArrayObjectAdapter
import androidx.lifecycle.lifecycleScope
import androidx.palette.graphics.Palette
import app.moviebase.tmdb.Tmdb3
import app.moviebase.tmdb.model.AppendResponse
import app.moviebase.tmdb.model.TmdbCredits
import app.moviebase.tmdb.model.TmdbEpisode
import app.moviebase.tmdb.model.TmdbResult
import app.moviebase.tmdb.model.TmdbSeason
import app.moviebase.tmdb.model.TmdbShowDetail
import app.moviebase.tmdb.model.TmdbVideo
import com.anthonyessaye.opentv.Activities.DetailActivities.MovieDetailActivity
import com.anthonyessaye.opentv.Activities.DetailActivities.TvDetailActivity
import com.anthonyessaye.opentv.Activities.ListAllActivities.ListAllEpisodesActivity
import com.anthonyessaye.opentv.Adapters.MovieCardView
import com.anthonyessaye.opentv.Builders.XtreamBuilder
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Models.CastMember
import com.anthonyessaye.opentv.Models.MovieResponse
import com.anthonyessaye.opentv.Models.PaletteColors
import com.anthonyessaye.opentv.Models.Series.SeriesDetails
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.Persistence.Server.Server
import com.anthonyessaye.opentv.Persistence.User.User
import com.anthonyessaye.opentv.Presenters.CustomDetailPresenter
import com.anthonyessaye.opentv.Presenters.MoviePresenter
import com.anthonyessaye.opentv.Presenters.PersonPresenter
import com.anthonyessaye.opentv.Presenters.TvDetailDescriptionPresenter
import com.anthonyessaye.opentv.R
import com.anthonyessaye.opentv.REST.APIKeys
import com.anthonyessaye.opentv.REST.RESTHandler
import com.anthonyessaye.opentv.REST.TMDBRESTHandler
import com.anthonyessaye.opentv.TMDBHelper
import com.anthonyessaye.opentv.Utils.PaletteUtils
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DataSource
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.load.engine.GlideException
import com.bumptech.glide.request.RequestListener
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.target.Target
import com.bumptech.glide.request.transition.Transition
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Very lightweight detail fragment for TV shows.  */
class TvDetailFragment: DetailsSupportFragment(), Palette.PaletteAsyncListener,
OnItemViewClickedListener, PlayerInterface {
    private lateinit var tvShow: Series
    var tmdbDetails: TmdbShowDetail? = null
    var showDetails: SeriesDetails? = null
    var palette: PaletteColors? = null
    var arrayObjectAdapter: ArrayObjectAdapter? = null
    var customDetailPresenter: CustomDetailPresenter? = null
    var detailsOverviewRow: DetailsOverviewRow? = null
    var castAdapter: ArrayObjectAdapter = ArrayObjectAdapter(PersonPresenter())
    var mRecommendationsAdapter: ArrayObjectAdapter = ArrayObjectAdapter(MoviePresenter())
    var mRecommendationsRow: ListRow? = null
    var youtubeID: String? = null

    private val mGlideDrawableSimpleTarget: CustomTarget<Drawable?> = object : CustomTarget<Drawable?>() {
            override fun onResourceReady(
                resource: Drawable,
                transition: Transition<in Drawable?>?
            ) {
                detailsOverviewRow!!.setImageDrawable(resource)
            }

            override fun onLoadCleared(placeholder: Drawable?) {
                // no-op
            }
        }



    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        tvShow = requireActivity().intent.getSerializableExtra(TvDetailActivity.SERIES) as Series
        setUpAdapter()

        DatabaseManager().openDatabase(requireContext()) { db ->
            lifecycleScope.launch(Dispatchers.IO) {
                val user = db.userDao().getAll().first()
                val server = db.serverDao().getAll().first()

                val answerPair = getSeriesDetails(user, server, tvShow)
                showDetails = answerPair.first
                tmdbDetails = answerPair.second

                withContext(Dispatchers.Main) {
                    setUpDetailsOverviewRow()
                    setUpCastMembers()
                    setupRecommendationsRow()
                    setOnItemViewClickedListener(this@TvDetailFragment)
                    (requireActivity() as TvDetailActivity).updateBackground(showDetails!!)
                    (requireActivity() as TvDetailActivity).constraintLayoutLoading.visibility =
                        View.GONE
                }
            }
        }
    }

    private fun setUpAdapter() {
        customDetailPresenter =
            CustomDetailPresenter(TvDetailDescriptionPresenter(), DetailsOverviewLogoPresenter())
        val helper: FullWidthDetailsOverviewSharedElementHelper =
            FullWidthDetailsOverviewSharedElementHelper()
        helper.setSharedElementEnterTransition(getActivity(), TRANSITION_NAME)
        customDetailPresenter!!.setListener(helper)
        customDetailPresenter!!.setParticipatingEntranceTransition(false)

        customDetailPresenter!!.setOnActionClickedListener(OnActionClickedListener { action: Action? ->
            val actionId = action!!.getId().toInt()
            if (actionId == 0) {
                val intent = Intent(activity, ListAllEpisodesActivity::class.java)
                intent.putExtra(TvDetailActivity.SERIES_DETAIL, showDetails)
                intent.putExtra(TvDetailActivity.SERIES, tvShow)
                startActivity(intent)
            } else if (actionId == 1) {
                if (youtubeID != null) {
                    val youtubeURL = "https://www.youtube.com/watch?v=" + youtubeID
                    startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            youtubeURL.toUri()
                        )
                    )
                }
            }


        })

        val selector: ClassPresenterSelector = ClassPresenterSelector()
        selector.addClassPresenter(DetailsOverviewRow::class.java, customDetailPresenter)
        selector.addClassPresenter(ListRow::class.java, ListRowPresenter())
        arrayObjectAdapter = ArrayObjectAdapter(selector)
        setAdapter(arrayObjectAdapter)
    }

    suspend fun getSeriesDetails(user: User, server: Server, tvShow: Series): Pair<SeriesDetails?,TmdbShowDetail> {

        val tmdb = Tmdb3(APIKeys.TMDB_API_KEY)
        val tmdbSeriesDetail = tmdb.show.getDetails(
            showId = tvShow.tmdb!!.toInt(),
            language = "EN",
            appendResponses = listOf(
                AppendResponse.IMAGES,
                AppendResponse.TV_CREDITS,
                AppendResponse.VIDEOS,
                AppendResponse.CREDITS,
                AppendResponse.RELEASES_DATES
            )
        )

        var recommendations = TMDBRESTHandler.getRecommendations(tvShow.tmdb.toInt(), "tv")
        bindRecommendations(recommendations.component3().get())

        val xtream = XtreamBuilder(user.username, user.password, server.buildURL())
        val seriesDetails: SeriesDetails? = RESTHandler.SeriesREST.getSeriesDetails(xtream, tvShow.series_id.toString())

        return Pair(seriesDetails, tmdbSeriesDetail)
    }

    private fun setupRecommendationsRow() {
        mRecommendationsRow =
            ListRow(HeaderItem(2, getString(R.string.recommendations)), mRecommendationsAdapter)
        arrayObjectAdapter!!.add(mRecommendationsRow!!)
    }

    private fun bindRecommendations(response: MovieResponse) {
        mRecommendationsAdapter.addAll(0, response.getResults())
        if (response.getResults() == null || response.getResults().isEmpty()) {
            arrayObjectAdapter!!.remove(mRecommendationsRow!!)
        }
    }

    private fun fetchCastMembers() {
        bindCastMembers(tmdbDetails!!.credits)
    }

    private fun setUpCastMembers() {
        arrayObjectAdapter!!.add(ListRow(HeaderItem(0, getString(R.string.cast)), castAdapter))
        fetchCastMembers()
    }

    private fun bindCastMembers(response: TmdbCredits?) {
        if(response != null) {
            castAdapter.addAll(0, response.cast)
        }
    }

    private fun setUpDetailsOverviewRow() {
        detailsOverviewRow = DetailsOverviewRow(tvShow)
        arrayObjectAdapter!!.add(detailsOverviewRow!!)

        loadImage(TMDBHelper.POSTER_URL + tmdbDetails!!.posterPath)
        fetchShowDetails()
    }

    private fun fetchShowDetails() {
        bindShowDetails(tmdbDetails!!)
    }

    private fun bindShowDetails(tmdbShowDetail: TmdbShowDetail) {
        this.tmdbDetails = tmdbShowDetail
        detailsOverviewRow!!.setItem(this.tmdbDetails!!)
        fetchVideos()
    }

    private fun fetchVideos() {
        handleVideoResponse(tmdbDetails!!.videos)
    }

    private fun handleVideoResponse(response: TmdbResult<TmdbVideo>?) {
        val adapter: SparseArrayObjectAdapter = SparseArrayObjectAdapter()
        adapter.set(0, Action(0, getString(R.string.choose_season), null, null))

        if (response != null) {
            youtubeID = getTrailer(response.results, "official");

            if (youtubeID == null) {
                youtubeID = getTrailer(response.results, "trailer");
            }

            if (youtubeID == null) {
                youtubeID = getTrailerByType(response.results, "trailer");
            }

            if (youtubeID != null) {

                adapter.set(1, Action(1, getString(R.string.watch_trailer), null, null))
            }
        }

        detailsOverviewRow!!.setActionsAdapter(adapter);
        notifyDetailsChanged();
    }


    private fun getTrailer(videos: List<TmdbVideo>, keyword: String): String? {
        var id: String? = null

        for(video in videos) {
            if (video.name!!.lowercase().contains(keyword)) {
                id = video.key
            }
        }

        return id;
    }

    private fun getTrailerByType(videos: List<TmdbVideo>, keyword: String): String? {
        var id: String? = null

        for(video in videos) {
            if (video.type!!.name.lowercase().contains(keyword)) {
                id = video.key
            }
        }

        return id;
    }

    private fun loadImage(url: String?) {
        if (url == null || url.isEmpty()) {
            Glide.with(this@TvDetailFragment)
                .load(R.drawable.popcorn)
                .into<CustomTarget<Drawable?>?>(mGlideDrawableSimpleTarget)
            return
        }
        Glide.with(this@TvDetailFragment)
            .load(url)
            .diskCacheStrategy(DiskCacheStrategy.ALL)
            .placeholder(R.drawable.popcorn)
            .listener(object : RequestListener<Drawable?> {
                override fun onLoadFailed(
                    e: GlideException?,
                    model: Any?,
                    target: Target<Drawable?>,
                    isFirstResource: Boolean
                ): Boolean {
                    return false
                }

                override fun onResourceReady(
                    resource: Drawable,
                    model: Any,
                    target: Target<Drawable?>?,
                    dataSource: DataSource,
                    isFirstResource: Boolean
                ): Boolean {
                    if (resource is BitmapDrawable) {
                        changePalette(resource.getBitmap())
                    }
                    return false
                }
            })
            .into<CustomTarget<Drawable?>?>(mGlideDrawableSimpleTarget)
    }

    private fun changePalette(bmp: Bitmap) {
        Palette.from(bmp).generate(this)
    }

    override fun onGenerated(palette: Palette?) {
        val colors = PaletteUtils.getPaletteColors(palette)
        customDetailPresenter!!.setActionsBackgroundColor(colors.statusBarColor)
        customDetailPresenter!!.setBackgroundColor(colors.toolbarBackgroundColor)
        this.palette = colors
        notifyDetailsChanged()
    }

    private fun notifyDetailsChanged() {
        detailsOverviewRow!!.setItem(this.tmdbDetails!!)
        val index = arrayObjectAdapter!!.indexOf(detailsOverviewRow!!)
        arrayObjectAdapter!!.notifyArrayItemRangeChanged(index, 1)
    }

    override fun onItemClicked(
        itemViewHolder: Presenter.ViewHolder,
        item: Any?,
        rowViewHolder: RowPresenter.ViewHolder?,
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
                    MovieDetailFragment.Companion.TRANSITION_NAME
                ).toBundle()
                requireActivity().startActivity(intent, bundle)
            } else {
                startActivity(intent)
            }
        } else if (item is CastMember) {
            val cast = item
            /*Intent intent = new Intent(getActivity(), PersonDetailActivity.class);
            intent.putExtra(CastMember.class.getSimpleName(), cast);
            startActivity(intent);*/
        }
    }

    companion object {
        var TRANSITION_NAME: String = "poster_transition"
    }
}

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
import app.moviebase.tmdb.model.TmdbResult
import app.moviebase.tmdb.model.TmdbVideo
import com.anthonyessaye.opentv.Activities.DetailActivities.MovieDetailActivity
import com.anthonyessaye.opentv.Models.MovieResponse
import com.anthonyessaye.opentv.Adapters.MovieCardView
import com.anthonyessaye.opentv.Enums.StreamType
import com.anthonyessaye.opentv.Interfaces.PlayerInterface
import com.anthonyessaye.opentv.Models.CastMember
import com.anthonyessaye.opentv.Models.MovieDetails
import com.anthonyessaye.opentv.Models.PaletteColors
import com.anthonyessaye.opentv.Persistence.DatabaseManager
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistory
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Presenters.CustomDetailPresenter
import com.anthonyessaye.opentv.Presenters.DetailDescriptionPresenter
import com.anthonyessaye.opentv.Presenters.MoviePresenter
import com.anthonyessaye.opentv.Presenters.PersonPresenter
import com.anthonyessaye.opentv.R
import com.anthonyessaye.opentv.REST.APIKeys
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

class MovieDetailFragment : DetailsSupportFragment(), Palette.PaletteAsyncListener,
    OnItemViewClickedListener, PlayerInterface {
    lateinit var mSelectedMovie: Movie
    lateinit var movieDetails: MovieDetails
    lateinit var palette: PaletteColors
    var arrayObjectAdapter: ArrayObjectAdapter? = null
    var customDetailPresenter: CustomDetailPresenter? = null
    var detailsOverviewRow: DetailsOverviewRow? = null
    var castAdapter: ArrayObjectAdapter = ArrayObjectAdapter(PersonPresenter())
    var mRecommendationsAdapter: ArrayObjectAdapter = ArrayObjectAdapter(MoviePresenter())
    var mRecommendationsRow: ListRow? = null
    var youtubeID: String? = null


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        mSelectedMovie = requireActivity().intent.getSerializableExtra(MovieDetailActivity.Companion.MOVIE) as Movie
        setUpAdapter()

        lifecycleScope.launch(Dispatchers.IO) {
            movieDetails = doTMDBCall(mSelectedMovie.tmdb!!.toInt())

            withContext(Dispatchers.Main) {
                setUpDetailsOverviewRow()
                setUpCastMembers()
                setupRecommendationsRow()
                setOnItemViewClickedListener(this@MovieDetailFragment)
                (requireActivity() as MovieDetailActivity).updateBackground(movieDetails)
                (requireActivity() as MovieDetailActivity).constraintLayoutLoading.visibility =
                    View.GONE
            }
        }


    }

    private fun setUpAdapter() {
        customDetailPresenter = CustomDetailPresenter(
            DetailDescriptionPresenter(),
            DetailsOverviewLogoPresenter()
        )

        val helper = FullWidthDetailsOverviewSharedElementHelper()
        helper.setSharedElementEnterTransition(getActivity(), TRANSITION_NAME)
        customDetailPresenter!!.setListener(helper)
        customDetailPresenter!!.setParticipatingEntranceTransition(false)

        customDetailPresenter!!.setOnActionClickedListener(OnActionClickedListener { action: Action? ->
            val actionId = action!!.getId().toInt()
            if (actionId == 0) {
                DatabaseManager().openDatabase(requireContext()) { db ->
                    val serverInfo = db.serverDao().getAll().first()
                    val loggedInUser = db.userDao().getAll().first()

                    // Write history to disk
                    lifecycleScope.launch(Dispatchers.IO) {
                        val movieHistory = MovieHistory(
                            mSelectedMovie.stream_id,
                            mSelectedMovie.name,
                            mSelectedMovie.container_extension,
                            (System.currentTimeMillis() / 1000).toString(),
                            mSelectedMovie.stream_icon.toString(),
                            "0"
                        )

                        db.movieHistoryDao().insertTop(50, movieHistory)

                        val streamURI = buildStreamURI(
                            serverInfo,
                            loggedInUser,
                            StreamType.MOVIE,
                            mSelectedMovie.stream_id,
                            mSelectedMovie.container_extension
                        )

                        play(requireContext(), streamURI)
                    }


                }
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

        val classPresenterSelector = ClassPresenterSelector()
        classPresenterSelector.addClassPresenter(
            DetailsOverviewRow::class.java,
            customDetailPresenter
        )
        classPresenterSelector.addClassPresenter(ListRow::class.java, ListRowPresenter())
        arrayObjectAdapter = ArrayObjectAdapter(classPresenterSelector)
        setAdapter(arrayObjectAdapter)
    }

    suspend fun doTMDBCall(movieId: Int): MovieDetails {
        val tmdb = Tmdb3(APIKeys.TMDB_API_KEY)
        val tmdbMovieDetail = tmdb.movies.getDetails(
            movieId = movieId,
            language = "EN",
            appendResponses = listOf(
                AppendResponse.IMAGES,
                AppendResponse.TV_CREDITS,
                AppendResponse.VIDEOS,
                AppendResponse.CREDITS,
                AppendResponse.RELEASES_DATES
        ))

        var recommendations = TMDBRESTHandler.getRecommendations(movieId, "movie")

        var movieDetail: MovieDetails = MovieDetails().setAdult(tmdbMovieDetail.adult)
            .setOverview(tmdbMovieDetail.overview)
            .setVideo(tmdbMovieDetail.video)
            .setGenres(tmdbMovieDetail.genres)
            .setTitle(tmdbMovieDetail.title)
            .setPopularity(tmdbMovieDetail.popularity)
            .setBudget(tmdbMovieDetail.budget)
            .setRuntime(tmdbMovieDetail.runtime)
            .setRevenue(tmdbMovieDetail.revenue)
            .setTagline(tmdbMovieDetail.tagline)
            .setStatus(tmdbMovieDetail.status.name)
            .setPosterPath(tmdbMovieDetail.posterPath)
            .setOriginalTitle(tmdbMovieDetail.originalTitle)
            .setOriginalLanguage(tmdbMovieDetail.originalLanguage)
            .setBackdropPath(tmdbMovieDetail.backdropPath)
            .setVoteCount(tmdbMovieDetail.voteCount)
            .setVoteAverage(tmdbMovieDetail.voteAverage)
            .setImdbId(tmdbMovieDetail.imdbId)
            .setCredits(tmdbMovieDetail.credits)
            .setVideos(tmdbMovieDetail.videos)

        if (tmdbMovieDetail.releaseDates != null && !tmdbMovieDetail.releaseDates!!.results.isEmpty()) {
            // WTH is this concatenation tho?
            movieDetail.setReleaseDate(tmdbMovieDetail.releaseDates!!.results.first().releaseDates.first().releaseDate.toString())
        }

        bindRecommendations(recommendations.component3().get())

        return movieDetail
    }


    private fun setUpDetailsOverviewRow() {
        detailsOverviewRow = DetailsOverviewRow(MovieDetails())
        arrayObjectAdapter!!.add(detailsOverviewRow!!)


        loadImage(TMDBHelper.POSTER_URL + movieDetails.poster_path)
        fetchMovieDetails()
    }


    private fun fetchMovieDetails() {
        bindMovieDetails(movieDetails)
    }

    private fun fetchCastMembers() {
        bindCastMembers(movieDetails.credits)
    }

    private fun setUpCastMembers() {
        arrayObjectAdapter!!.add(ListRow(HeaderItem(0, getString(R.string.cast)), castAdapter))
        fetchCastMembers()
    }

    private fun bindCastMembers(response: TmdbCredits?) {
        if(response != null) {
            castAdapter.addAll(0, response.cast)

            if (!response.crew.isEmpty()) {
                for (c in response.crew) {
                    if (c.job == getString(R.string.director)) {
                        movieDetails.setDirector(c.name)
                        notifyDetailsChanged()
                    }
                }
            }
        }
    }

    private fun bindMovieDetails(movieDetails: MovieDetails) {
        this.movieDetails = movieDetails
        detailsOverviewRow!!.setItem(this.movieDetails)
        fetchVideos()
    }

    private fun setupRecommendationsRow() {
        mRecommendationsRow =
            ListRow(HeaderItem(2, getString(R.string.recommendations)), mRecommendationsAdapter)
        arrayObjectAdapter!!.add(mRecommendationsRow!!)
        fetchRecommendations()
    }

    private fun fetchRecommendations() {
        /*theMovieDbAPI.getRecommendations(movie.getId(), Config.API_KEY_URL)
                .subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(this::bindRecommendations, e -> System.out.println(e.getMessage()));*/
    }

    private fun fetchVideos() {
        handleVideoResponse(movieDetails.videos)
    }

    private fun handleVideoResponse(response: TmdbResult<TmdbVideo>?) {
        val adapter: SparseArrayObjectAdapter = SparseArrayObjectAdapter()
        adapter.set(0, Action(0, getString(R.string.play), null, null))

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
    private fun bindRecommendations(response: MovieResponse) {
        mRecommendationsAdapter.addAll(0, response.getResults())
        if (response.getResults() == null || response.getResults().isEmpty()) {
            arrayObjectAdapter!!.remove(mRecommendationsRow!!)
        }
    }

    private val mGlideDrawableSimpleTarget: CustomTarget<Drawable?> =
        object : CustomTarget<Drawable?>() {
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


    private fun loadImage(url: String?) {
        if (url == null || url.isEmpty()) {
            Glide.with(this@MovieDetailFragment)
                .load(R.drawable.popcorn)
                .into<CustomTarget<Drawable?>?>(mGlideDrawableSimpleTarget)
            return
        }
        Glide.with(this@MovieDetailFragment)
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
        detailsOverviewRow!!.setItem(this.movieDetails)
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
                    TRANSITION_NAME
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

        @JvmStatic
        fun newInstance(movie: Movie?): MovieDetailFragment {
            val args = Bundle()
            //args.putParcelable(Movie.class.getSimpleName(), movie);
            val fragment = MovieDetailFragment()
            fragment.setArguments(args)
            return fragment
        }
    }
}
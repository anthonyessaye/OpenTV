package com.anthonyessaye.opentv.Activities.DetailActivities

import android.os.Bundle
import android.widget.FrameLayout
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import app.moviebase.tmdb.model.TmdbShowDetail
import com.anthonyessaye.opentv.Fragments.MovieDetailFragment
import com.anthonyessaye.opentv.Fragments.TvDetailFragment
import com.anthonyessaye.opentv.Models.MovieDetails
import com.anthonyessaye.opentv.Models.Series.SeriesDetails
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.Persistence.Series.Series
import com.anthonyessaye.opentv.R
import com.anthonyessaye.opentv.TMDBHelper
import com.anthonyessaye.opentv.Utils.GlideBackgroundManager

/** Activity displaying details for a TV show.  */
class TvDetailActivity : FragmentActivity() {
    lateinit var mainView: FrameLayout
    lateinit var constraintLayoutLoading: ConstraintLayout

    private var glideBackgroundManager: GlideBackgroundManager? = null
    private var tvShow: Series? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detail)

        tvShow = this.getIntent().getSerializableExtra(TvDetailActivity.SERIES) as Series?
        mainView = findViewById<FrameLayout>(R.id.details_fragment)
        constraintLayoutLoading = findViewById<ConstraintLayout>(R.id.constraintLayoutLoading)

        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.details_fragment, TvDetailFragment())
                .commitNow()
        }

        glideBackgroundManager = GlideBackgroundManager(this)
    }

    protected override fun onResume() {
        super.onResume()
    }

    public fun updateBackground(tvShowDetail: SeriesDetails) {
        if (tvShow!!.backdrop_path != null) {
            glideBackgroundManager!!.loadImage(TMDBHelper.BACKDROP_URL + tvShowDetail.info.backdrop_path)
        } else {
            glideBackgroundManager!!.setBackground(
                ContextCompat.getDrawable(
                    this,
                    R.drawable.material_bg
                )
            )
        }
    }

    companion object {
        const val SERIES = "Series"
        const val SERIES_DETAIL = "SeriesDetail"
    }
}

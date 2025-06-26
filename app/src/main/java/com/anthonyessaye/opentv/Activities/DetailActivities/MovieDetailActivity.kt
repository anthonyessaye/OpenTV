package com.anthonyessaye.opentv.Activities.DetailActivities

import android.os.Bundle
import android.widget.FrameLayout
import androidx.cardview.widget.CardView
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.anthonyessaye.opentv.Models.MovieDetails
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.R
import com.anthonyessaye.opentv.TMDBHelper

class MovieDetailActivity : FragmentActivity() {
    lateinit var mainView: FrameLayout
    lateinit var constraintLayoutLoading: ConstraintLayout

    private var glideBackgroundManager: GlideBackgroundManager? = null
    private var movie: Movie? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detail)

        movie = this.getIntent().getSerializableExtra(MovieDetailActivity.MOVIE) as Movie?
        mainView = findViewById<FrameLayout>(R.id.details_fragment)
        constraintLayoutLoading = findViewById<ConstraintLayout>(R.id.constraintLayoutLoading)

        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.details_fragment, MovieDetailFragment())
                .commitNow()
        }

        glideBackgroundManager = GlideBackgroundManager(this)
    }

    override fun onResume() {
        super.onResume()
    }

    public fun updateBackground(movieDetails: MovieDetails) {
        if (movieDetails.backdrop_path != null) {
            glideBackgroundManager!!.loadImage(TMDBHelper.BACKDROP_URL + movieDetails.backdrop_path);
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
        const val SHARED_ELEMENT_NAME = "hero"
        const val MOVIE = "Movie"
        const val LIVE_STREAM = "LIVE_STREAM"
    }
}

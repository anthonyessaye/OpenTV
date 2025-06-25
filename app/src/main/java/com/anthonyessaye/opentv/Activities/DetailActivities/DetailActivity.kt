package com.anthonyessaye.opentv.Activities.DetailActivities

import android.os.Bundle
import androidx.cardview.widget.CardView
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.anthonyessaye.opentv.Persistence.Movie.Movie
import com.anthonyessaye.opentv.R

class DetailActivity : FragmentActivity() {
    lateinit var cardView: CardView

    private var glideBackgroundManager: GlideBackgroundManager? = null
    private var movie: Movie? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detail)

        movie = this.getIntent().getSerializableExtra(DetailActivity.MOVIE) as Movie?

        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.details_fragment, DetailFragment())
                .commitNow()
        }

        glideBackgroundManager = GlideBackgroundManager(this)
        updateBackground()
    }

    override fun onResume() {
        super.onResume()
        updateBackground()
    }

    private fun updateBackground() {
        glideBackgroundManager!!.setBackground(
            ContextCompat.getDrawable(
                this,
                R.drawable.material_bg
            )
        )
        if (movie != null) {// && movie.back != null) {
            //glideBackgroundManager.loadImage(HttpClientModule.BACKDROP_URL + movie.getBackdropPath());
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

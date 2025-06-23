package com.anthonyessaye.opentv.Activities

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import com.anthonyessaye.opentv.R
import com.anthonyessaye.opentv.Fragments.VideoDetailsFragment

/**
 * Details activity class that loads [VideoDetailsFragment] class.
 */
class DetailsActivity : FragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_details)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.details_fragment, VideoDetailsFragment())
                .commitNow()
        }
    }

    companion object {
        const val SHARED_ELEMENT_NAME = "hero"
        const val MOVIE = "Movie"
        const val LIVE_STREAM = "LIVE_STREAM"
    }
}
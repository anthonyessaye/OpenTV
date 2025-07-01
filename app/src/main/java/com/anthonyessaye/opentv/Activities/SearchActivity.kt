package com.anthonyessaye.opentv.Activities

import android.content.Intent
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import com.anthonyessaye.opentv.Fragments.SearchFragment
import com.anthonyessaye.opentv.R

/**
 * Hosts the [SearchFragment] using the support Fragment API.
 */
class SearchActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_search)

        if (savedInstanceState == null) {
            getSupportFragmentManager().beginTransaction()
                .replace(R.id.search_fragment, SearchFragment.newInstance())
                .commit()
        }
    }

    override fun onSearchRequested(): Boolean {
        startActivity(Intent(this, SearchActivity::class.java))
        return true
    }
}

package com.anthonyessaye.opentv.Activities

import android.os.Bundle
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.fragment.app.FragmentActivity
import com.anthonyessaye.opentv.Fragments.MainFragment
import com.anthonyessaye.opentv.R

/**
 * Loads [MainFragment].
 */
class MainActivity : FragmentActivity() {

    internal lateinit var relativeLayoutLoader: RelativeLayout
    internal lateinit var textViewInformation: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        relativeLayoutLoader = findViewById<RelativeLayout>(R.id.relativeLayoutLoader)
        textViewInformation = findViewById<TextView>(R.id.textViewInformation)

        if (savedInstanceState == null) {
            getSupportFragmentManager().beginTransaction()
                .replace(R.id.main_browse_fragment, MainFragment())
                .commitNow()
        }
    }
}
package com.anthonyessaye.opentv.Activities;

import android.content.Intent;
import android.os.Bundle;

import androidx.fragment.app.FragmentActivity;

import com.anthonyessaye.opentv.Fragments.SearchFragment;
import com.anthonyessaye.opentv.R;

/**
 * Hosts the {@link SearchFragment} using the support Fragment API.
 */
public class SearchActivity extends FragmentActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_search);

        if (savedInstanceState == null) {
            getSupportFragmentManager().beginTransaction()
                    .replace(R.id.search_fragment, SearchFragment.newInstance())
                    .commit();
        }
    }

    @Override
    public boolean onSearchRequested() {
        startActivity(new Intent(this, SearchActivity.class));
        return true;
    }
}

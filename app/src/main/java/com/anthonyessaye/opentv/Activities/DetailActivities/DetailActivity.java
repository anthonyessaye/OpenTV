package com.anthonyessaye.opentv.Activities.DetailActivities;

import android.os.Bundle;
import android.widget.Toast;

import androidx.core.content.ContextCompat;

import com.anthonyessaye.opentv.Activities.DetailsActivity;
import com.anthonyessaye.opentv.Persistence.Movie.Movie;
import com.anthonyessaye.opentv.R;

public class DetailActivity extends BaseTVActivity {

    private GlideBackgroundManager glideBackgroundManager;
    private Movie movie;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        movie = (Movie) this.getIntent().getSerializableExtra(DetailsActivity.MOVIE);
        DetailFragment detailsFragment = DetailFragment.newInstance(movie);
        addFragment(detailsFragment);

        glideBackgroundManager = new GlideBackgroundManager(this);
        updateBackground();
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateBackground();
    }

    private void updateBackground() {
        if (movie != null) { //&& movie.getBackdropPath() != null) {
            Toast.makeText(this, "SOMETHING NEEDS TO BE DONE HERE", Toast.LENGTH_LONG).show();
            //glideBackgroundManager.loadImage(HttpClientModule.BACKDROP_URL + movie.getBackdropPath());
        } else {
            glideBackgroundManager.setBackground(ContextCompat.getDrawable(this, R.drawable.material_bg));
        }
    }
}

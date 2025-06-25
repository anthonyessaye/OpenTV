package com.anthonyessaye.opentv.Activities.DetailActivities;

import static java.security.AccessController.getContext;

import android.content.Context;
import android.widget.ImageView;
import android.widget.TextView;

import com.anthonyessaye.opentv.Persistence.Movie.Movie;
import com.anthonyessaye.opentv.R;
import com.anthonyessaye.opentv.TMDBHelper;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;

public class MovieCardView extends BindableCardView<Movie> {

    ImageView mPosterIV;
    TextView title_tv;

    public MovieCardView(Context context) {
        super(context);
        mPosterIV = findViewById(R.id.poster_iv);
        title_tv = findViewById(R.id.title_tv);
    }

    @Override
    protected void bind(Movie movie) {
        String posterPath = null;// movie.getPosterPath();
        if (posterPath == null || posterPath.isEmpty()) {
            Glide.with(getContext())
                    .load(R.drawable.popcorn)
                    .into(mPosterIV);
        } else {

            Glide.with(getContext())
                    .load(TMDBHelper.POSTER_URL + posterPath)
                    .diskCacheStrategy(DiskCacheStrategy.ALL)
                    .placeholder(R.drawable.popcorn)
                    .into(mPosterIV);
        }
        title_tv.setText(movie.getName());
    }

    public ImageView getPosterIV() {
        return mPosterIV;
    }

    @Override
    protected int getLayoutResource() {
        return R.layout.card_movie;
    }
}
package com.anthonyessaye.opentv.Adapters;

import android.content.Context;
import android.widget.ImageView;
import android.widget.TextView;

import com.anthonyessaye.opentv.Models.MovieDetails;
import com.anthonyessaye.opentv.R;
import com.anthonyessaye.opentv.TMDBHelper;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;

public class MovieCardView extends BindableCardView<MovieDetails> {

    ImageView mPosterIV;
    TextView title_tv;

    public MovieCardView(Context context) {
        super(context);
        mPosterIV = findViewById(R.id.poster_iv);
        title_tv = findViewById(R.id.title_tv);
    }

    @Override
    public void bind(MovieDetails movie) {
        String posterPath = movie.getPoster_path();
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
        title_tv.setText(movie.getTitle());
    }

    public ImageView getPosterIV() {
        return mPosterIV;
    }

    @Override
    protected int getLayoutResource() {
        return R.layout.card_movie;
    }
}
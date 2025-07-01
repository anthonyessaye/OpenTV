package com.anthonyessaye.opentv.Adapters;

import android.content.Context;
import android.widget.ImageView;
import android.widget.TextView;

import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream;
import com.anthonyessaye.opentv.Persistence.Movie.Movie;
import com.anthonyessaye.opentv.R;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;

public class SearchMovieCardView extends BindableCardView<Movie> {

    ImageView mPosterIV;
    TextView title_tv;

    public SearchMovieCardView(Context context) {
        super(context);
        mPosterIV = findViewById(R.id.poster_iv);
        title_tv = findViewById(R.id.title_tv);
    }

    @Override
    public void bind(Movie movie) {
        String posterPath = movie.getStream_icon();
        if (posterPath == null || posterPath.isEmpty()) {
            Glide.with(getContext())
                    .load(R.drawable.popcorn)
                    .fitCenter()
                    .into(mPosterIV);
        } else {
            Glide.with(getContext())
                    .load(posterPath)
                    .diskCacheStrategy(DiskCacheStrategy.ALL)
                    .placeholder(R.drawable.popcorn)
                    .fitCenter()
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

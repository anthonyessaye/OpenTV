package com.anthonyessaye.opentv.Adapters;

import android.content.Context;
import android.widget.ImageView;
import android.widget.TextView;

import com.anthonyessaye.opentv.Persistence.Movie.Movie;
import com.anthonyessaye.opentv.Persistence.Series.Series;
import com.anthonyessaye.opentv.R;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;

public class SearchSeriesCardView extends BindableCardView<Series> {

    ImageView mPosterIV;
    TextView title_tv;

    public SearchSeriesCardView(Context context) {
        super(context);
        mPosterIV = findViewById(R.id.poster_iv);
        title_tv = findViewById(R.id.title_tv);
    }

    @Override
    public void bind(Series series) {
        String posterPath = series.getCover();
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
        title_tv.setText(series.getName());
    }

    public ImageView getPosterIV() {
        return mPosterIV;
    }

    @Override
    protected int getLayoutResource() {
        return R.layout.card_movie;
    }
}
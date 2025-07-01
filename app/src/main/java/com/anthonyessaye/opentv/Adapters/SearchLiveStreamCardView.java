package com.anthonyessaye.opentv.Adapters;

import android.content.Context;
import android.widget.ImageView;
import android.widget.TextView;

import com.anthonyessaye.opentv.Models.MovieDetails;
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream;
import com.anthonyessaye.opentv.R;
import com.anthonyessaye.opentv.TMDBHelper;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;

public class SearchLiveStreamCardView extends BindableCardView<LiveStream> {

    ImageView mPosterIV;
    TextView title_tv;

    public SearchLiveStreamCardView(Context context) {
        super(context);
        mPosterIV = findViewById(R.id.poster_iv);
        title_tv = findViewById(R.id.title_tv);

        mPosterIV.setBackgroundColor(getResources().getColor(R.color.minor_color_blue));
        mPosterIV.setScaleType(ImageView.ScaleType.FIT_CENTER);
    }

    @Override
    public void bind(LiveStream stream) {
        String posterPath = stream.getStream_icon();
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
        title_tv.setText(stream.getName());
    }

    public ImageView getPosterIV() {
        return mPosterIV;
    }

    @Override
    protected int getLayoutResource() {
        return R.layout.card_movie;
    }
}

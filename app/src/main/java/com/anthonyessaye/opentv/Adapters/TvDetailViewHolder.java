package com.anthonyessaye.opentv.Adapters;

import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.leanback.widget.Presenter;

import com.anthonyessaye.opentv.Persistence.Series.Series;
import com.anthonyessaye.opentv.R;

import java.util.Locale;

import app.moviebase.tmdb.model.TmdbShowDetail;


public class TvDetailViewHolder extends Presenter.ViewHolder {

    TextView titleTv;
    TextView yearTv;
    TextView overviewTv;
    TextView ratingTv;
    TextView taglineTv;
    LinearLayout genresLayout;

    private final View itemView;

    public TvDetailViewHolder(View view) {
        super(view);
        itemView = view;
        titleTv = itemView.findViewById(R.id.movie_title);
        yearTv = itemView.findViewById(R.id.movie_year);
        overviewTv = itemView.findViewById(R.id.overview);
        ratingTv = itemView.findViewById(R.id.rating);
        taglineTv = itemView.findViewById(R.id.tagline);
        genresLayout = itemView.findViewById(R.id.genres);
    }

    public void bind(TmdbShowDetail show) {
        titleTv.setText(show.getName());
        if (show.getFirstAirDate() != null && show.getFirstAirDate().toString().length() >= 4) {
            yearTv.setText(String.format(Locale.getDefault(), "(%s)", show.getFirstAirDate().toString().substring(0, 4)));
        }
        overviewTv.setText(show.getOverview());
        ratingTv.setText(String.format(Locale.getDefault(), "%.1f/10", show.getVoteAverage()));
        taglineTv.setVisibility(View.GONE);
        genresLayout.removeAllViews();
    }
}

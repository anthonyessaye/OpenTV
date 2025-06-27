package com.anthonyessaye.opentv.Presenters;

import androidx.leanback.widget.Presenter;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.anthonyessaye.opentv.Adapters.DetailViewHolder;
import com.anthonyessaye.opentv.Adapters.TvDetailViewHolder;
import com.anthonyessaye.opentv.Persistence.Series.Series;
import com.anthonyessaye.opentv.R;

import app.moviebase.tmdb.model.TmdbShowDetail;


/** Presenter responsible for binding TV show details. */
public class TvDetailDescriptionPresenter extends Presenter {

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.fragment_movie_detail, parent, false);
        return new TvDetailViewHolder(view);
    }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, Object item) {
        TmdbShowDetail tvShow = (TmdbShowDetail) item;
        TvDetailViewHolder holder = (TvDetailViewHolder) viewHolder;
        holder.bind(tvShow);
    }

    @Override
    public void onUnbindViewHolder(ViewHolder viewHolder) {}
}

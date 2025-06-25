package com.anthonyessaye.opentv.Activities.DetailActivities;

import androidx.leanback.widget.Presenter;

import android.view.ViewGroup;

import com.anthonyessaye.opentv.Persistence.Movie.Movie;

public class MoviePresenter extends Presenter {

    public MoviePresenter() {}

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent) {
        return new ViewHolder(new MovieCardView(parent.getContext()));
    }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, Object item) {
        ((MovieCardView) viewHolder.view).bind((Movie) item);
    }

    @Override
    public void onUnbindViewHolder(ViewHolder viewHolder) {}
}

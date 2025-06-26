package com.anthonyessaye.opentv.Presenters;

import androidx.leanback.widget.Presenter;

import android.view.ViewGroup;

import com.anthonyessaye.opentv.Adapters.MovieCardView;
import com.anthonyessaye.opentv.Models.MovieDetails;

public class MoviePresenter extends Presenter {

    public MoviePresenter() {}

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent) {
        return new ViewHolder(new MovieCardView(parent.getContext()));
    }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, Object item) {
        ((MovieCardView) viewHolder.view).bind((MovieDetails) item);
    }

    @Override
    public void onUnbindViewHolder(ViewHolder viewHolder) {}
}

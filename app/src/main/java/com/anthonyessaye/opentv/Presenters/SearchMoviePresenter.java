package com.anthonyessaye.opentv.Presenters;

import android.view.ViewGroup;

import androidx.leanback.widget.Presenter;

import com.anthonyessaye.opentv.Adapters.SearchLiveStreamCardView;
import com.anthonyessaye.opentv.Adapters.SearchMovieCardView;
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream;
import com.anthonyessaye.opentv.Persistence.Movie.Movie;

public class SearchMoviePresenter extends Presenter {

    public SearchMoviePresenter() {}

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent) {
        return new ViewHolder(new SearchMovieCardView(parent.getContext()));
    }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, Object item) {
        ((SearchMovieCardView) viewHolder.view).bind((Movie) item);

    }

    @Override
    public void onUnbindViewHolder(ViewHolder viewHolder) {}
}
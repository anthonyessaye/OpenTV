package com.anthonyessaye.opentv.Presenters;

import android.view.ViewGroup;

import androidx.leanback.widget.Presenter;

import com.anthonyessaye.opentv.Adapters.SearchMovieCardView;
import com.anthonyessaye.opentv.Adapters.SearchSeriesCardView;
import com.anthonyessaye.opentv.Persistence.Movie.Movie;
import com.anthonyessaye.opentv.Persistence.Series.Series;

public class SearchSeriesPresenter extends Presenter {

    public SearchSeriesPresenter() {}

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent) {
        return new ViewHolder(new SearchSeriesCardView(parent.getContext()));
    }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, Object item) {
        ((SearchSeriesCardView) viewHolder.view).bind((Series) item);

    }

    @Override
    public void onUnbindViewHolder(ViewHolder viewHolder) {}
}
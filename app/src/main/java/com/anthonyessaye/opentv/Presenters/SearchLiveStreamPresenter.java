package com.anthonyessaye.opentv.Presenters;

import android.view.ViewGroup;

import androidx.cardview.widget.CardView;
import androidx.leanback.widget.Presenter;

import com.anthonyessaye.opentv.Adapters.MovieCardView;
import com.anthonyessaye.opentv.Adapters.SearchLiveStreamCardView;
import com.anthonyessaye.opentv.Models.MovieDetails;
import com.anthonyessaye.opentv.Persistence.LiveStream.LiveStream;


public class SearchLiveStreamPresenter extends Presenter {

    public SearchLiveStreamPresenter() {}

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent) {
        return new ViewHolder(new SearchLiveStreamCardView(parent.getContext()));
    }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, Object item) {
        ((SearchLiveStreamCardView) viewHolder.view).bind((LiveStream) item);

    }

    @Override
    public void onUnbindViewHolder(ViewHolder viewHolder) {}
}

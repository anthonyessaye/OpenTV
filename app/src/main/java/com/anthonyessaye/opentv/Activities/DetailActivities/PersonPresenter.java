package com.anthonyessaye.opentv.Activities.DetailActivities;

import android.content.Context;

import androidx.appcompat.view.ContextThemeWrapper;
import androidx.leanback.widget.ImageCardView;
import androidx.leanback.widget.Presenter;
import android.view.ViewGroup;

import com.anthonyessaye.opentv.Models.CastMember;
import com.anthonyessaye.opentv.R;
import com.anthonyessaye.opentv.TMDBHelper;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;

import app.moviebase.tmdb.model.TmdbCast;


public class PersonPresenter extends Presenter {

    Context context;

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent) {
        if (context == null) {
            context = new ContextThemeWrapper(parent.getContext(), R.style.PersonCardTheme);
        }
        ImageCardView view = new ImageCardView(context);
        view.setMainImageDimensions(200, 300);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(ViewHolder viewHolder, Object item) {
        ImageCardView imageCardView = (ImageCardView) viewHolder.view;
        TmdbCast castMember = (TmdbCast) item;

        Glide.with(imageCardView.getContext())
                .load(TMDBHelper.POSTER_URL + castMember.getProfilePath())
                .diskCacheStrategy(DiskCacheStrategy.ALL)
                .into(imageCardView.getMainImageView());

        imageCardView.setTitleText(castMember.getName());
        imageCardView.setContentText(castMember.getCharacter());
    }

    @Override
    public void onUnbindViewHolder(ViewHolder viewHolder) {}
}

package com.anthonyessaye.opentv.Activities.DetailActivities;

import android.os.Parcel;
import android.os.Parcelable;

import com.anthonyessaye.opentv.Models.MovieDetails;
import com.anthonyessaye.opentv.Persistence.Movie.Movie;

import java.io.Serializable;
import java.util.List;

import app.moviebase.tmdb.model.TmdbMovie;


public class MovieResponse implements Serializable {

    private int page;
    private List<MovieDetails> results;
    private int total_pages;
    private int total_results;

    public int getPage() {
        return page;
    }

    public MovieResponse setPage(int page) {
        this.page = page;
        return this;
    }

    public List<MovieDetails> getResults() {
        return results;
    }

    public MovieResponse setResults(List<MovieDetails> results) {
        this.results = results;
        return this;
    }

    public int getTotalPages() {
        return total_pages;
    }

    public MovieResponse setTotalPages(int total_pages) {
        this.total_pages = total_pages;
        return this;
    }

    public int getTotalResults() {
        return total_results;
    }

    public MovieResponse setTotalResults(int totalResults) {
        this.total_results = totalResults;
        return this;
    }
}

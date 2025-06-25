package com.anthonyessaye.opentv.Models

class MovieDetails {
    var isAdult: Boolean = false
        private set
    var overview: String? = null
        private set
    var isVideo: Boolean = false
        private set
    var genres: MutableList<Genre?>? = null
        private set
    var title: String? = null
        private set
    var popularity: Float = 0f
        private set
    var budget: Int = 0
        private set
    var runtime: Int = 0
        private set
    var revenue: Int = 0
        private set
    var tagline: String? = null
        private set
    var status: String? = null
        private set
    var release_date: String? = null
        private set
    var poster_path: String? = null
        private set
    var original_title: String? = null
        private set
    var original_language: String? = null
        private set
    var backdrop_path: String? = null
        private set
    var vote_count: Int = 0
        private set
    var vote_average: Float = 0f
        private set
    var imdb_id: String? = null
        private set

    private var paletteColors: PaletteColors? = null
    var director: String? = null
        private set

    fun setAdult(adult: Boolean): MovieDetails {
        this.isAdult = adult
        return this
    }

    fun setOverview(overview: String?): MovieDetails {
        this.overview = overview
        return this
    }

    fun setVideo(video: Boolean): MovieDetails {
        this.isVideo = video
        return this
    }

    fun setGenres(genres: MutableList<Genre?>?): MovieDetails {
        this.genres = genres
        return this
    }

    fun setTitle(title: String?): MovieDetails {
        this.title = title
        return this
    }

    fun setPopularity(popularity: Float): MovieDetails {
        this.popularity = popularity
        return this
    }

    fun setBudget(budget: Int): MovieDetails {
        this.budget = budget
        return this
    }

    fun setRuntime(runtime: Int): MovieDetails {
        this.runtime = runtime
        return this
    }

    fun setRevenue(revenue: Int): MovieDetails {
        this.revenue = revenue
        return this
    }

    fun setTagline(tagline: String?): MovieDetails {
        this.tagline = tagline
        return this
    }

    fun setStatus(status: String?): MovieDetails {
        this.status = status
        return this
    }

    fun setReleaseDate(release_date: String?): MovieDetails {
        this.release_date = release_date!!
        return this
    }

    fun setPosterPath(poster_path: String?): MovieDetails {
        this.poster_path = poster_path!!
        return this
    }

    fun setOriginalTitle(original_title: String?): MovieDetails {
        this.original_title = original_title!!
        return this
    }

    fun setOriginalLanguage(original_language: String?): MovieDetails {
        this.original_language = original_language
        return this
    }

    fun setBackdropPath(backdrop_path: String?): MovieDetails {
        this.backdrop_path = backdrop_path
        return this
    }

    fun setVoteCount(vote_count: Int): MovieDetails {
        this.vote_count = vote_count
        return this
    }

    fun setVoteAverage(vote_average: Float): MovieDetails {
        this.vote_average = vote_average
        return this
    }

    fun setImdbId(imdb_id: String?): MovieDetails {
        this.imdb_id = imdb_id
        return this
    }

    fun getPaletteColors(): PaletteColors? {
        return paletteColors
    }

    fun setPaletteColors(paletteColors: PaletteColors?): MovieDetails {
        this.paletteColors = paletteColors
        return this
    }

    fun setDirector(director: String?): MovieDetails {
        this.director = director
        return this
    }
}

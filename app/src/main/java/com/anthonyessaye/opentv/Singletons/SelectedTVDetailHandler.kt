package com.anthonyessaye.opentv.Singletons

import com.anthonyessaye.opentv.Models.Series.SeriesDetails
import com.anthonyessaye.opentv.Persistence.Series.Series

object SelectedTVDetailHandler {
    private var showDetails: SeriesDetails? = null
    private var tvShow: Series? = null

    fun setSelectedTVDetailHandler(showDetails: SeriesDetails?, tvShow: Series?) {
        this.showDetails = showDetails
        this.tvShow = tvShow
    }

    fun getShowDetails(): SeriesDetails? {
        return this.showDetails
    }

    fun getTVShow(): Series? {
        return this.tvShow
    }
}
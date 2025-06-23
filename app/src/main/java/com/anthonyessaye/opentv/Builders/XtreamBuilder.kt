package com.anthonyessaye.opentv.Builders

class XtreamBuilder(private val username: String,
                    private val password: String,
                    private val host: String) {

    private fun getBaseURL(): String {
        return "$host/player_api.php?username=$username&password=$password"
    }

    public fun getUserInfoURL(): String {
        return getBaseURL()
    }

    public fun getAllLiveStreamURL(): String {
        return "${getBaseURL()}&action=get_live_streams"
    }

    public fun getAllLiveCategoriesURL(): String {
        return "${getBaseURL()}&action=get_live_categories"
    }

    public fun getStreamsForSpecificLiveCategoriesURL(id: String): String {
        return "${getBaseURL()}&action=get_live_streams&category_id=$id"
    }

    public fun getAllMoviesURL(): String {
        return "${getBaseURL()}&action=get_vod_streams"
    }

    public fun getAllMovieCategoriesURL(): String {
        return "${getBaseURL()}&action=get_vod_categories"
    }

    public fun getStreamsForSpecificMovieCategoriesURL(id: String): String {
        return "${getBaseURL()}&action=get_vod_streams&category_id=$id"
    }

    public fun getStreamInfoForSpecificMovie(movieiD: String): String {
        return "${getBaseURL()}&action=get_vod_info&vod_id=$movieiD"
    }

    public fun getAllSeriesURL(): String {
        return "${getBaseURL()}&action=get_series"
    }

    public fun getAllSeriesCategoriesURL(): String {
        return "${getBaseURL()}&action=get_series_categories"
    }

    public fun getStreamsForSpecificSeiresCategoriesURL(id: String): String {
        return "${getBaseURL()}&action=get_series&category_id=$id"
    }

    public fun getStreamInfoForSpecificSeries(seriesID: String): String {
        return "${getBaseURL()}&action=get_series_info&series=$seriesID"
    }

    /*

Get full EPG list for ALL Streams :

Request : <url>/xmltv.php?username=<user>&password=<pwd>
Exemple : http://xtreamcode.ex/xmltv.php?username=Mike&password=1234
Get short EPG for a dedicated live streams :

Request : <url>/player_api.php?username=<user>&password=<pwd>&action=get_short_epg&stream_id=36475
can add &limit=<X> param (default=4)
Exemple : http://xtreamcode.ex/player_api.php?username=Mike&password=1234&action=get_short_epg&stream_id=55555
Get full EPG for a dedicated live stream :

Request : <url>/player_api.php?username=<user>&password=<pwd>&action=get_simple_date_table&stream_id=<X>
Exemple : http://xtreamcode.ex/player_api.php?username=Mike&password=1234&action=get_simple_date_table&stream_id=55555
     */

}
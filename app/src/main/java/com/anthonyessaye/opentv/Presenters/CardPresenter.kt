package com.anthonyessaye.opentv.Presenters

import android.graphics.drawable.Drawable
import android.util.Log
import android.view.ViewGroup
import android.widget.ImageView
import androidx.core.content.ContextCompat
import androidx.leanback.widget.ImageCardView
import androidx.leanback.widget.Presenter
import com.anthonyessaye.opentv.Persistence.History.LiveHistory.LiveHistory
import com.anthonyessaye.opentv.Persistence.History.MovieHistory.MovieHistory
import com.anthonyessaye.opentv.R
import com.bumptech.glide.Glide
import com.github.marlonlom.utilities.timeago.TimeAgo
import kotlin.properties.Delegates

/**
 * A CardPresenter is used to generate Views and bind Objects to them on demand.
 * It contains an ImageCardView.
 */
class CardPresenter() : Presenter() {
    private var mDefaultCardImage: Drawable? = null
    private var sSelectedBackgroundColor: Int by Delegates.notNull()
    private var sDefaultBackgroundColor: Int by Delegates.notNull()

    override fun onCreateViewHolder(parent: ViewGroup): ViewHolder {
        Log.d(TAG, "onCreateViewHolder")

        sDefaultBackgroundColor = ContextCompat.getColor(parent.context, R.color.minor_color_blue)
        sSelectedBackgroundColor =
            ContextCompat.getColor(parent.context, R.color.minor_color_green)
        mDefaultCardImage = ContextCompat.getDrawable(parent.context, R.drawable.default_cover)

        val cardView = object : ImageCardView(parent.context) {
            override fun setSelected(selected: Boolean) {
                updateCardBackgroundColor(this, selected)
                super.setSelected(selected)
            }
        }

        cardView.isFocusable = true
        cardView.isFocusableInTouchMode = true

        updateCardBackgroundColor(cardView, false)
        return ViewHolder(cardView)
    }

    override fun onBindViewHolder(viewHolder: ViewHolder, item: Any?) {
        if (item is LiveHistory) {
            val liveStream = item as LiveHistory

            val cardView = viewHolder.view as ImageCardView
            cardView.titleText = liveStream.name
            cardView.contentText = TimeAgo.Companion.using(liveStream.last_watched.toLong() * 1000)

            cardView.setMainImageDimensions(SPECIAL_CARD_WIDTH, CARD_HEIGHT)


            cardView.mainImageView!!.scaleType = ImageView.ScaleType.FIT_CENTER

            Glide.with(viewHolder.view.context)
                .load(liveStream.stream_icon)
                .fitCenter()
                .error(mDefaultCardImage)
                .into(cardView.mainImageView!!)
        }

        if (item is MovieHistory) {
            val movie = item as MovieHistory

            val cardView = viewHolder.view as ImageCardView
            cardView.titleText = movie.name
            cardView.contentText = TimeAgo.Companion.using(movie.last_watched.toLong() * 1000)

            cardView.setMainImageDimensions(SPECIAL_CARD_WIDTH, CARD_HEIGHT)


            cardView.mainImageView!!.scaleType = ImageView.ScaleType.CENTER_CROP

            Glide.with(viewHolder.view.context)
                .load(movie.stream_icon)
                .centerCrop()
                .error(mDefaultCardImage)
                .into(cardView.mainImageView!!)
        }

        if (item is String) {
            val cardView = viewHolder.view as ImageCardView
            cardView.titleText = item
            cardView.setMainImageDimensions(SPECIAL_CARD_WIDTH, CARD_HEIGHT)
            cardView.mainImageView!!.setImageResource(R.drawable.view_all)
        }
    }


    override fun onUnbindViewHolder(viewHolder: ViewHolder) {
        Log.d(TAG, "onUnbindViewHolder")
        val cardView = viewHolder.view as ImageCardView
        // Remove references to images so that the garbage collector can free up memory
        cardView.badgeImage = null
        cardView.mainImage = null
    }

    private fun updateCardBackgroundColor(view: ImageCardView, selected: Boolean) {
        val color = if (selected) sSelectedBackgroundColor else sDefaultBackgroundColor
        // Both background colors should be set because the view"s background is temporarily visible
        // during animations.
        view.setBackgroundColor(color)
        view.setInfoAreaBackgroundColor(color)
    }

    companion object {
        private val TAG = "CardPresenter"

        private val CARD_WIDTH = 108
        private val CARD_HEIGHT = 192
        private val SPECIAL_CARD_WIDTH = CARD_HEIGHT
    }
}
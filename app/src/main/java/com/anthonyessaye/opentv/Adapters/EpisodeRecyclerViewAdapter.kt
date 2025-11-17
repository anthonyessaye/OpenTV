package com.anthonyessaye.opentv.Adapters

import android.content.Intent
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.SeekBar
import android.widget.TextView
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.RecyclerView.LayoutManager
import app.moviebase.tmdb.model.TmdbEpisode
import com.anthonyessaye.opentv.Adapters.EpisodeRecyclerViewAdapter.ViewHolder
import com.anthonyessaye.opentv.Enums.RecyclerViewType
import com.anthonyessaye.opentv.Helper
import com.anthonyessaye.opentv.Interfaces.RecyclerViewCallbackInterface
import com.anthonyessaye.opentv.Models.Series.Episode
import com.anthonyessaye.opentv.R
import com.bumptech.glide.Glide

class EpisodeRecyclerViewAdapter(private val tmdbEpisodes: List<Episode>,
                                 private val episodeIDToPositionPair: HashMap<Int, String>,
                                 private val parentInterface: RecyclerViewCallbackInterface,
                                 private val recyclerViewType: RecyclerViewType) : RecyclerView.Adapter<ViewHolder>()  {

    private var selectedItem = -1
    private var longClickedItem = -1
    private var hoverItem = 0

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val imageViewCover: ImageView
        val textViewTitle: TextView
        val textViewDescription: TextView
        val seekBar: SeekBar
        //val root: ConstraintLayout

        init {
            // Define click listener for the ViewHolder's View
            imageViewCover = view.findViewById(R.id.imageViewEpisode)
            textViewTitle = view.findViewById(R.id.textViewTitle)
            textViewDescription = view.findViewById(R.id.textViewDescription)
            seekBar = view.findViewById(R.id.seekBar)
            //root = view.findViewById(R.id.root)

        }
    }

    // Create new views (invoked by the layout manager)
    override fun onCreateViewHolder(viewGroup: ViewGroup, viewType: Int): ViewHolder {
        // Create a new view, which defines the UI of the list item
        val view = LayoutInflater.from(viewGroup.context)
            .inflate(R.layout.cell_episode_recycler_view, viewGroup, false)

        view.isFocusable = true
        view.isFocusableInTouchMode = true

        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {

        // Get element from your dataset at this position and replace the
        // contents of the view with that element
        val adapterPosition = holder.bindingAdapterPosition

        holder.textViewTitle.text = tmdbEpisodes[adapterPosition].title
        holder.textViewDescription.text = tmdbEpisodes[adapterPosition].info.duration
        holder.itemView.setSelected(selectedItem == adapterPosition);
        holder.itemView.isHovered = hoverItem == adapterPosition

        if (recyclerViewType != RecyclerViewType.LIST_CATEGORIES) {
            holder.itemView.setBackgroundResource(R.drawable.item_list_no_background)
        }

        holder.itemView.setOnFocusChangeListener { view, isFocused ->
            // add focus handling logic
            if(isFocused && adapterPosition != selectedItem) {
                hoverItem = adapterPosition
                //holder.textView.isSelected = true
                holder.itemView.setBackgroundResource(R.drawable.item_hover_shape)
            } else {
                //holder.textView.isSelected = false
                holder.itemView.setBackgroundResource(R.drawable.item_list_selection)
            }
        }

        holder.itemView.setOnClickListener {
            notifyItemChanged(selectedItem);
            selectedItem = adapterPosition
            notifyItemChanged(selectedItem);

            buildIntent(selectedItem, false)
        }

        holder.itemView.setOnLongClickListener {
            longClickedItem = adapterPosition
            buildIntent(longClickedItem, true)
            return@setOnLongClickListener true
        }

        Glide.with(holder.itemView.context)
            .load(tmdbEpisodes[adapterPosition].info.movie_image)
            .fitCenter()
            .error(R.drawable.default_cover)
            .into(holder.imageViewCover)

        if (episodeIDToPositionPair[tmdbEpisodes[adapterPosition].id.toInt()] != null) {
            val episodePosition = episodeIDToPositionPair[tmdbEpisodes[adapterPosition].id.toInt()]

            holder.seekBar.max = tmdbEpisodes[adapterPosition].info.duration_secs
            holder.seekBar.visibility = View.VISIBLE
            holder.seekBar.setProgress((episodePosition!!.toLong()/1000).toInt())
        }

        else {
            holder.seekBar.visibility = View.GONE
        }
    }

    fun buildIntent(index: Int, longClick: Boolean) {
        val intent = Intent()
        intent.putExtra(Helper.KEY_RECYCLER_VIEW_TYPE, recyclerViewType.name)
        intent.putExtra(Helper.KEY_ID, tmdbEpisodes[index].id)
        intent.putExtra(Helper.LONG_PRESS, longClick)

        parentInterface.processIntent(intent)
    }

    override fun onAttachedToRecyclerView(recyclerView: RecyclerView) {
        super.onAttachedToRecyclerView(recyclerView)

        recyclerView.setOnKeyListener(object : View.OnKeyListener {
            public override fun onKey(p0: View?, p1: Int, p2: KeyEvent?): Boolean {
                val lm = recyclerView.getLayoutManager()

                // Return false if scrolled to the bounds and allow focus to move off the list
                if (p2!!.getAction() == KeyEvent.ACTION_DOWN) {
                    if (p1 == KeyEvent.KEYCODE_DPAD_DOWN) {
                        return tryMoveSelection(lm!!, 1)
                    } else if (p1 == KeyEvent.KEYCODE_DPAD_UP) {
                        return tryMoveSelection(lm!!, -1)
                    }
                }

                return false
            }
        })
    }

    private fun tryMoveSelection(lm: LayoutManager, direction: Int) : Boolean {
        var nextSelectItem: Int = selectedItem + direction;

        // If still within valid bounds, move the selection, notify to redraw, and scroll
        if (nextSelectItem >= 0 && nextSelectItem <= getItemCount()) {
            notifyItemChanged(selectedItem);
            selectedItem = nextSelectItem;
            notifyItemChanged(selectedItem);
            lm.scrollToPosition(selectedItem);
            return true;
        }

        return false;
    }

    // Return the size of your dataset (invoked by the layout manager)
    override fun getItemCount() = tmdbEpisodes.size

}
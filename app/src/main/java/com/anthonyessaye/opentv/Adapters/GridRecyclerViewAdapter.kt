package com.anthonyessaye.opentv.Adapters

import android.content.Intent
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.RecyclerView.LayoutManager
import com.anthonyessaye.opentv.Enums.RecyclerViewType
import com.anthonyessaye.opentv.Helper
import com.anthonyessaye.opentv.Interfaces.RecyclerViewCallbackInterface
import com.anthonyessaye.opentv.R
import com.bumptech.glide.Glide

class GridRecyclerViewAdapter(private val dataSet: Array<Pair<String, String>>,
                              private val images: Array<String>,
                              private val parentInterface: RecyclerViewCallbackInterface,
                              private val recyclerViewType: RecyclerViewType) :
    RecyclerView.Adapter<GridRecyclerViewAdapter.ViewHolder>()  {

    private var selectedItem = -1
    private var longClickedItem = -1
    private var hoverItem = 0

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val imageViewCover: ImageView
        val textView: TextView
        val root: ConstraintLayout

        init {
            // Define click listener for the ViewHolder's View
            imageViewCover = view.findViewById(R.id.imageViewCover)
            textView = view.findViewById(R.id.textView)
            root = view.findViewById(R.id.root)

        }
    }

    // Create new views (invoked by the layout manager)
    override fun onCreateViewHolder(viewGroup: ViewGroup, viewType: Int): ViewHolder {
        // Create a new view, which defines the UI of the list item
        val view = LayoutInflater.from(viewGroup.context)
            .inflate(R.layout.cell_grid_recycler_view, viewGroup, false)

        view.isFocusable = true
        view.isFocusableInTouchMode = true

        return ViewHolder(view)
    }


    // Replace the contents of a view (invoked by the layout manager)
    override fun onBindViewHolder(viewHolder: ViewHolder, position: Int) {

        // Get element from your dataset at this position and replace the
        // contents of the view with that element
        val adapterPosition = viewHolder.bindingAdapterPosition

        viewHolder.textView.text = dataSet[adapterPosition].component2()
        viewHolder.root.setSelected(selectedItem == adapterPosition);
        viewHolder.root.isHovered = hoverItem == adapterPosition

        if (recyclerViewType != RecyclerViewType.LIST_CATEGORIES) {
            viewHolder.itemView.setBackgroundResource(R.drawable.item_list_no_background)
        }

        viewHolder.itemView.setOnFocusChangeListener { view, isFocused ->
            // add focus handling logic
            if(isFocused && adapterPosition != selectedItem) {
                hoverItem = adapterPosition
                viewHolder.textView.isSelected = true
                viewHolder.root.setBackgroundResource(R.drawable.item_hover_shape)
            } else {
                viewHolder.textView.isSelected = false
                viewHolder.root.setBackgroundResource(R.drawable.item_list_selection)
            }
        }

        viewHolder.itemView.setOnClickListener {
            notifyItemChanged(selectedItem);
            selectedItem = adapterPosition
            notifyItemChanged(selectedItem);

            buildIntent(selectedItem, false)
        }

        viewHolder.itemView.setOnLongClickListener {
            longClickedItem = adapterPosition
            buildIntent(longClickedItem, true)
            return@setOnLongClickListener true
        }

        Glide.with(viewHolder.imageViewCover.context)
            .load(images[adapterPosition])
            .fitCenter()
            .error(R.drawable.default_cover)
            .into(viewHolder.imageViewCover)
    }

    fun buildIntent(index: Int, longClick: Boolean) {
        val intent = Intent()
        intent.putExtra(Helper.KEY_RECYCLER_VIEW_TYPE, recyclerViewType.name)
        intent.putExtra(Helper.KEY_ID, dataSet[index].component1())
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
    override fun getItemCount() = dataSet.size

}
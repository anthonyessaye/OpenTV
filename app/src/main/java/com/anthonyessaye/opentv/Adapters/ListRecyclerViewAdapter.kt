package com.anthonyessaye.opentv.Adapters

import android.content.Intent
import android.graphics.drawable.Drawable
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

class ListRecyclerViewAdapter(private val dataSet: Array<Pair<String, String>>,
                              private val favoriteIDs: List<Int>,
                              private val parentInterface: RecyclerViewCallbackInterface,
                              private val recyclerViewType: RecyclerViewType) :
    RecyclerView.Adapter<ListRecyclerViewAdapter.ViewHolder>()  {

    private var selectedItem = 0
    private var longClickedItem = 0
    private var hoverItem = 0
    private var hasInitialized = false

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val textView: TextView
        val root: ConstraintLayout
        val imageViewFavorite: ImageView

        init {
            // Define click listener for the ViewHolder's View
            textView = view.findViewById(R.id.textView)
            root = view.findViewById(R.id.root)
            imageViewFavorite = view.findViewById<ImageView>(R.id.imageViewFavorite)
        }
    }

    // Create new views (invoked by the layout manager)
    override fun onCreateViewHolder(viewGroup: ViewGroup, viewType: Int): ViewHolder {
        // Create a new view, which defines the UI of the list item
        val view = LayoutInflater.from(viewGroup.context)
            .inflate(R.layout.cell_list_recycler_view, viewGroup, false)


        if (dataSet.any() {it.component2().contains("-//OpenTV-")} || recyclerViewType != RecyclerViewType.LIST_CATEGORIES) {
            selectedItem = -1
        }

        view.isFocusable = true
        view.isFocusableInTouchMode = true

        return ViewHolder(view)
    }


    // Replace the contents of a view (invoked by the layout manager)
    override fun onBindViewHolder(viewHolder: ViewHolder, position: Int) {
        val adapterPosition = viewHolder.bindingAdapterPosition
        val currentItemId = dataSet[adapterPosition].first.toInt()

        val seasonName = dataSet[adapterPosition].component2()
        viewHolder.textView.text = seasonName

        if (seasonName.contains("-//OpenTV-")) {
            val data = seasonName.split("-//OpenTV-")
            viewHolder.textView.text = data.last()

            if (!hasInitialized) {
                selectedItem = adapterPosition
                hoverItem = selectedItem
                buildIntent(selectedItem, false)
                hasInitialized = true
            }
        }

        viewHolder.root.setSelected(selectedItem == adapterPosition);
        viewHolder.root.isHovered = hoverItem == adapterPosition

        if (recyclerViewType != RecyclerViewType.LIST_CATEGORIES) {
            viewHolder.itemView.setBackgroundResource(R.drawable.item_list_no_background)

            viewHolder.imageViewFavorite.visibility = View.GONE
            if (favoriteIDs.contains(currentItemId))
                viewHolder.imageViewFavorite.visibility = View.VISIBLE

            viewHolder.itemView.setOnLongClickListener {
                longClickedItem = adapterPosition
                buildIntent(longClickedItem, true)
                return@setOnLongClickListener true
            }
        }

        viewHolder.itemView.setOnClickListener {
            if (recyclerViewType == RecyclerViewType.LIST_CATEGORIES) {
                notifyItemChanged(selectedItem);
                selectedItem = adapterPosition
                notifyItemChanged(selectedItem);
            }

            buildIntent(adapterPosition, false)
        }


        viewHolder.itemView.setOnFocusChangeListener { view, isFocused ->
            // add focus handling logic
            if(isFocused && adapterPosition != selectedItem) {
                hoverItem = adapterPosition
                viewHolder.textView.isSelected = true
                view.setBackgroundResource(R.drawable.item_hover_shape)
            } else {
                viewHolder.textView.isSelected = false
                view.setBackgroundResource(R.drawable.item_list_selection)
            }
        }
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

package com.anthonyessaye.opentv.Models

import android.os.Parcel
import android.os.Parcelable
import java.io.Serializable

class PaletteColors : Serializable {
    var toolbarBackgroundColor: Int = 0
        private set
    var statusBarColor: Int = 0
        private set
    var textColor: Int = 0
        private set
    var titleColor: Int = 0
        private set

    fun setToolbarBackgroundColor(toolbarBackgroundColor: Int): PaletteColors {
        this.toolbarBackgroundColor = toolbarBackgroundColor
        return this
    }

    fun setStatusBarColor(statusBarColor: Int): PaletteColors {
        this.statusBarColor = statusBarColor
        return this
    }

    fun setTextColor(textColor: Int): PaletteColors {
        this.textColor = textColor
        return this
    }

    fun setTitleColor(titleColor: Int): PaletteColors {
        this.titleColor = titleColor
        return this
    }
}

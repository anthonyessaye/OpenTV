package com.anthonyessaye.opentv.Utils

import android.graphics.Color
import androidx.palette.graphics.Palette
import com.anthonyessaye.opentv.Models.PaletteColors

object PaletteUtils {
    fun getPaletteColors(palette: Palette?): PaletteColors {
        val paletteColors = PaletteColors()

        //figuring out toolbar palette color in order of preference
        if (palette != null) {
            if (palette.darkVibrantSwatch != null) {
                paletteColors.setToolbarBackgroundColor(palette.darkVibrantSwatch!!.getRgb())
                paletteColors.setTextColor(palette.darkVibrantSwatch!!.getBodyTextColor())
                paletteColors.setTitleColor(palette.darkVibrantSwatch!!.getTitleTextColor())
            } else if (palette.darkMutedSwatch != null) {
                paletteColors.setToolbarBackgroundColor(palette.darkMutedSwatch!!.getRgb())
                paletteColors.setTextColor(palette.darkMutedSwatch!!.getBodyTextColor())
                paletteColors.setTitleColor(palette.darkMutedSwatch!!.getTitleTextColor())
            } else if (palette.vibrantSwatch != null) {
                paletteColors.setToolbarBackgroundColor(palette.vibrantSwatch!!.getRgb())
                paletteColors.setTextColor(palette.vibrantSwatch!!.getBodyTextColor())
                paletteColors.setTitleColor(palette.vibrantSwatch!!.getTitleTextColor())
            }
        }

        //set the status bar color to be a darker version of the toolbar background Color;
        if (paletteColors.toolbarBackgroundColor != 0) {
            val hsv = FloatArray(3)
            val color = paletteColors.toolbarBackgroundColor
            Color.colorToHSV(color, hsv)
            // value component
            hsv[2] *= 0.8f
            paletteColors.setStatusBarColor(Color.HSVToColor(hsv))
        }

        return paletteColors
    }
}

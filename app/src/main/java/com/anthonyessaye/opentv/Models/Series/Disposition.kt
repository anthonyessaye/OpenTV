package com.anthonyessaye.opentv.Models.Series

import java.io.Serializable

data class Disposition(val default: Int,
                       val  dub: Int,
                       val original: Int,
                       val comment: Int,
                       val lyrics: Int,
                       val karaoke: Int,
                       val forced: Int,
                       val hearing_impaired: Int,
                       val visual_impaired: Int,
                       val clean_effects: Int,
                       val attached_pic: Int,
                       val timed_thumbnails: Int,
                       val captions: Int,
                       val descriptions: Int,
                       val metadata: Int,
                       val dependent: Int,
                       val still_image: Int): Serializable

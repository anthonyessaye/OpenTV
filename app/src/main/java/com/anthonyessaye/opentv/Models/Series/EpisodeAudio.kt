package com.anthonyessaye.opentv.Models.Series

import java.io.Serializable

data class EpisodeAudio(val index: Int,
                        val codec_name: String,
                        val codec_long_name: String,
                        val codec_type: String,
                        val codec_tag_string: String,
                        val codec_tag: String,
                        val sample_fmt: String,
                        val sample_rate: String,
                        val channels: Int,
                        val channel_layout: String,
                        val bits_per_sample: Int,
                        val r_frame_rate: String,
                        val avg_frame_rate: String,
                        val time_base: String,
                        val start_pts: Int,
                        val start_time: String,
                        val bit_rate: String,
                        val disposition: Disposition,
                        val tags: Tags): Serializable



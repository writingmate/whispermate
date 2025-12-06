package com.whispermate.aidictation.domain.model

import com.squareup.moshi.JsonClass
import java.util.UUID

@JsonClass(generateAdapter = true)
data class Shortcut(
    val id: String = UUID.randomUUID().toString(),
    val voiceTrigger: String,
    val expansion: String,
    val isEnabled: Boolean = true
)

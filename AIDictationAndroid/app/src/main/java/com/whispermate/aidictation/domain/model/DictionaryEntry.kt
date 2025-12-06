package com.whispermate.aidictation.domain.model

import com.squareup.moshi.JsonClass
import java.util.UUID

@JsonClass(generateAdapter = true)
data class DictionaryEntry(
    val id: String = UUID.randomUUID().toString(),
    val trigger: String,
    val replacement: String? = null,
    val isEnabled: Boolean = true
)

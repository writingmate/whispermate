package com.whispermate.aidictation.domain.model

import com.squareup.moshi.JsonClass
import java.util.UUID

/**
 * App-specific formatting rules for transcription.
 * Rules can be applied based on which app the keyboard is being used in.
 */
@JsonClass(generateAdapter = true)
data class ContextRule(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val appPackageNames: List<String> = emptyList(), // Android package names like "com.whatsapp"
    val instructions: String,
    val isEnabled: Boolean = true
)

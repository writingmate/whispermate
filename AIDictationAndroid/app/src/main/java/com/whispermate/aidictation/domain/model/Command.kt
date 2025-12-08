package com.whispermate.aidictation.domain.model

import com.squareup.moshi.JsonClass
import java.util.UUID

/**
 * Represents a text transformation command that can be triggered either by voice or button.
 *
 * @param id Unique identifier for the command
 * @param name Display name (e.g., "Cleanup", "Rewrite")
 * @param voiceTriggers Phrases that trigger this command via voice (e.g., ["rewrite this", "rewrite it"])
 * @param systemPrompt LLM instruction for executing the command
 * @param iconRes Drawable resource ID for toolbar button (null = voice-only command)
 * @param isBuiltIn Whether this is a built-in command (cannot be deleted)
 * @param isEnabled Whether the command is currently enabled
 */
@JsonClass(generateAdapter = true)
data class Command(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val voiceTriggers: List<String>,
    val systemPrompt: String,
    val iconRes: Int? = null,
    val isBuiltIn: Boolean = false,
    val isEnabled: Boolean = true
)

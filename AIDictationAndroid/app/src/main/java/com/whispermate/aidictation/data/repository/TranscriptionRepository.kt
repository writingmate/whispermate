package com.whispermate.aidictation.data.repository

import com.whispermate.aidictation.data.preferences.AppPreferences
import com.whispermate.aidictation.data.remote.TranscriptionClient
import kotlinx.coroutines.flow.first
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TranscriptionRepository @Inject constructor(
    private val appPreferences: AppPreferences
) {
    suspend fun transcribe(audioFile: File, prompt: String? = null): Result<String> {
        return TranscriptionClient.transcribe(audioFile, prompt)
    }

    suspend fun buildPrompt(): String {
        val dictionary = appPreferences.dictionaryEntries.first()
            .filter { it.isEnabled }
            .map { it.trigger }

        val shortcuts = appPreferences.shortcuts.first()
            .filter { it.isEnabled }
            .map { it.voiceTrigger }

        val toneInstructions = appPreferences.toneStyles.first()
            .filter { it.isEnabled }
            .map { it.instructions }

        val parts = mutableListOf<String>()

        if (dictionary.isNotEmpty()) {
            parts.add("Vocabulary hints: ${dictionary.joinToString(", ")}")
        }

        if (shortcuts.isNotEmpty()) {
            parts.add("Common phrases: ${shortcuts.joinToString(", ")}")
        }

        if (toneInstructions.isNotEmpty()) {
            parts.add(toneInstructions.joinToString(". "))
        }

        return parts.joinToString(". ")
    }

    suspend fun applyPostProcessing(text: String): String {
        var result = text

        // Apply dictionary replacements
        val dictionary = appPreferences.dictionaryEntries.first()
            .filter { it.isEnabled && it.replacement != null }
            .sortedByDescending { it.trigger.length }

        for (entry in dictionary) {
            result = result.replace(entry.trigger, entry.replacement!!, ignoreCase = true)
        }

        // Apply shortcut expansions
        val shortcuts = appPreferences.shortcuts.first()
            .filter { it.isEnabled }
            .sortedByDescending { it.voiceTrigger.length }

        for (shortcut in shortcuts) {
            result = result.replace(shortcut.voiceTrigger, shortcut.expansion, ignoreCase = true)
        }

        return result
    }
}

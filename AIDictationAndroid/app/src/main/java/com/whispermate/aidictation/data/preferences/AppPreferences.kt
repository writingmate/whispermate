package com.whispermate.aidictation.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import com.whispermate.aidictation.domain.model.ContextRule
import com.whispermate.aidictation.domain.model.DictionaryEntry
import com.whispermate.aidictation.domain.model.Shortcut
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

@Singleton
class AppPreferences @Inject constructor(
    @ApplicationContext private val context: Context,
    private val moshi: Moshi
) {
    private object Keys {
        val HAS_COMPLETED_ONBOARDING = booleanPreferencesKey("has_completed_onboarding")
        val DICTIONARY_ENTRIES = stringPreferencesKey("dictionary_entries")
        val TONE_STYLES = stringPreferencesKey("tone_styles")
        val CONTEXT_RULES = stringPreferencesKey("context_rules")
        val SHORTCUTS = stringPreferencesKey("shortcuts")
        val API_KEY = stringPreferencesKey("api_key")
    }

    // Onboarding
    val hasCompletedOnboarding: Flow<Boolean> = context.dataStore.data.map { preferences ->
        preferences[Keys.HAS_COMPLETED_ONBOARDING] ?: false
    }

    suspend fun setOnboardingCompleted(completed: Boolean) {
        context.dataStore.edit { preferences ->
            preferences[Keys.HAS_COMPLETED_ONBOARDING] = completed
        }
    }

    // Dictionary Entries
    private val dictionaryEntryListType = Types.newParameterizedType(List::class.java, DictionaryEntry::class.java)
    private val dictionaryEntryAdapter = moshi.adapter<List<DictionaryEntry>>(dictionaryEntryListType)

    val dictionaryEntries: Flow<List<DictionaryEntry>> = context.dataStore.data.map { preferences ->
        val json = preferences[Keys.DICTIONARY_ENTRIES]
        if (json.isNullOrEmpty()) {
            defaultDictionaryEntries
        } else {
            dictionaryEntryAdapter.fromJson(json) ?: defaultDictionaryEntries
        }
    }

    suspend fun saveDictionaryEntries(entries: List<DictionaryEntry>) {
        context.dataStore.edit { preferences ->
            preferences[Keys.DICTIONARY_ENTRIES] = dictionaryEntryAdapter.toJson(entries)
        }
    }

    // Context Rules (previously called ToneStyles)
    private val contextRuleListType = Types.newParameterizedType(List::class.java, ContextRule::class.java)
    private val contextRuleAdapter = moshi.adapter<List<ContextRule>>(contextRuleListType)

    val contextRules: Flow<List<ContextRule>> = context.dataStore.data.map { preferences ->
        // Try new key first, then fall back to old key for migration
        val json = preferences[Keys.CONTEXT_RULES] ?: preferences[Keys.TONE_STYLES]
        if (json.isNullOrEmpty()) {
            defaultContextRules
        } else {
            contextRuleAdapter.fromJson(json) ?: defaultContextRules
        }
    }

    suspend fun saveContextRules(rules: List<ContextRule>) {
        context.dataStore.edit { preferences ->
            preferences[Keys.CONTEXT_RULES] = contextRuleAdapter.toJson(rules)
        }
    }

    // Backward compatibility aliases
    val toneStyles: Flow<List<ContextRule>> get() = contextRules

    suspend fun saveToneStyles(styles: List<ContextRule>) = saveContextRules(styles)

    /**
     * Get combined instructions for a specific app package.
     * Returns instructions from all matching enabled rules:
     * - Rules with empty appPackageNames (apply to all apps)
     * - Rules that match the current app's package name
     */
    suspend fun getInstructionsForApp(packageName: String?): String? {
        val rules = contextRules.first()

        val matchingRules = rules.filter { rule ->
            if (!rule.isEnabled) return@filter false

            // If no app restrictions, apply to all
            if (rule.appPackageNames.isEmpty()) return@filter true

            // Check if current app matches
            packageName != null && rule.appPackageNames.contains(packageName)
        }

        if (matchingRules.isEmpty()) return null

        return matchingRules.joinToString(". ") { it.instructions }
    }

    // Shortcuts
    private val shortcutListType = Types.newParameterizedType(List::class.java, Shortcut::class.java)
    private val shortcutAdapter = moshi.adapter<List<Shortcut>>(shortcutListType)

    val shortcuts: Flow<List<Shortcut>> = context.dataStore.data.map { preferences ->
        val json = preferences[Keys.SHORTCUTS]
        if (json.isNullOrEmpty()) {
            defaultShortcuts
        } else {
            shortcutAdapter.fromJson(json) ?: defaultShortcuts
        }
    }

    suspend fun saveShortcuts(shortcuts: List<Shortcut>) {
        context.dataStore.edit { preferences ->
            preferences[Keys.SHORTCUTS] = shortcutAdapter.toJson(shortcuts)
        }
    }

    companion object {
        val defaultDictionaryEntries = listOf(
            DictionaryEntry(trigger = "AI dictation", replacement = "AIDictation", isEnabled = false),
            DictionaryEntry(trigger = "open AI", replacement = "OpenAI", isEnabled = false),
            DictionaryEntry(trigger = "chat GPT", replacement = "ChatGPT", isEnabled = false),
            DictionaryEntry(trigger = "API", replacement = null, isEnabled = false),
            DictionaryEntry(trigger = "iOS", replacement = null, isEnabled = false),
            DictionaryEntry(trigger = "JSON", replacement = null, isEnabled = false),
        )

        val defaultShortcuts = listOf(
            Shortcut(voiceTrigger = "my email", expansion = "your.email@example.com", isEnabled = false),
            Shortcut(voiceTrigger = "my phone", expansion = "+1 (555) 123-4567", isEnabled = false),
            Shortcut(voiceTrigger = "my address", expansion = "123 Main Street, City, State 12345", isEnabled = false),
        )

        val defaultContextRules = listOf(
            // Speech cleanup rules (global, apply to all apps)
            ContextRule(
                name = "Remove filler words",
                appPackageNames = emptyList(),
                instructions = "Remove filler words like 'um', 'uh', 'like', 'you know', 'basically', 'actually'.",
                isEnabled = false
            ),
            ContextRule(
                name = "Clean up repetitions",
                appPackageNames = emptyList(),
                instructions = "Clean up stutters and repeated words or phrases.",
                isEnabled = false
            ),
            ContextRule(
                name = "Fix self-corrections",
                appPackageNames = emptyList(),
                instructions = "When someone corrects themselves mid-sentence ('no actually', 'I mean', 'wait'), keep only the final corrected version.",
                isEnabled = false
            ),
            ContextRule(
                name = "Remove hedging",
                appPackageNames = emptyList(),
                instructions = "Remove hedging language like 'I think', 'maybe', 'sort of', 'kind of'.",
                isEnabled = false
            ),
            ContextRule(
                name = "Remove weak phrases",
                appPackageNames = emptyList(),
                instructions = "Remove weak phrases like 'I mean', talking in circles, unnecessary qualifiers.",
                isEnabled = false
            ),
            ContextRule(
                name = "Reduce adverbs",
                appPackageNames = emptyList(),
                instructions = "Reduce overused adverbs like 'really', 'very', 'literally'.",
                isEnabled = false
            ),
        )
    }
}

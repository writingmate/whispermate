package com.whispermate.aidictation.data.remote

import android.util.Log
import com.whispermate.aidictation.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

object SuggestionClient {
    private const val TAG = "SuggestionClient"

    private val okHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .writeTimeout(5, TimeUnit.SECONDS)
            .build()
    }

    private val completionPrompt = """You are a keyboard autocomplete assistant. The user is typing a word. Complete it.

Rules:
- Return exactly 3 complete words that START with the partial word being typed
- Each suggestion must be exactly ONE word (no phrases, no spaces)
- Keep suggestions relevant and common
- No explanations, no punctuation, just 3 single words on separate lines"""

    private val nextWordPrompt = """You are a keyboard autocomplete assistant. Suggest the next word the user might type.

Rules:
- Return exactly 3 likely next words based on context
- Each suggestion must be exactly ONE word (no phrases, no spaces)
- Keep suggestions relevant and common
- No explanations, no punctuation, just 3 single words on separate lines"""

    suspend fun getSuggestions(text: String, isCompletingWord: Boolean): Result<List<String>> = withContext(Dispatchers.IO) {
        try {
            val apiKey = BuildConfig.GROQ_API_KEY
            if (apiKey.isEmpty()) {
                return@withContext Result.failure(Exception("Groq API key not configured"))
            }

            if (text.isBlank()) {
                return@withContext Result.success(emptyList())
            }

            val prompt = if (isCompletingWord) completionPrompt else nextWordPrompt
            val userMessage = if (isCompletingWord) {
                val partialWord = text.trimEnd().split(" ").lastOrNull() ?: ""
                "Context: \"$text\"\nComplete the word: \"$partialWord\""
            } else {
                "Context: \"$text\"\nSuggest the next word."
            }

            val requestJson = JSONObject().apply {
                put("model", BuildConfig.GROQ_MODEL)
                put("messages", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "system")
                        put("content", prompt)
                    })
                    put(JSONObject().apply {
                        put("role", "user")
                        put("content", userMessage)
                    })
                })
                put("max_tokens", 50)
                put("temperature", 0.3)
                put("reasoning_effort", "low")
            }

            val request = Request.Builder()
                .url(BuildConfig.GROQ_ENDPOINT)
                .addHeader("Authorization", "Bearer $apiKey")
                .addHeader("Content-Type", "application/json")
                .post(requestJson.toString().toRequestBody("application/json".toMediaType()))
                .build()

            val response = okHttpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "Suggestion request failed: ${response.code} - $errorBody")
                return@withContext Result.failure(Exception("Suggestion request failed: ${response.code}"))
            }

            val responseBody = response.body?.string() ?: "{}"
            Log.d(TAG, "Raw response: $responseBody")
            val json = JSONObject(responseBody)
            val message = json
                .getJSONArray("choices")
                .getJSONObject(0)
                .getJSONObject("message")

            // gpt-oss models put output in "reasoning" field, not "content"
            val content = if (message.has("reasoning") && message.optString("content").isEmpty()) {
                message.getString("reasoning").trim()
            } else {
                message.getString("content").trim()
            }

            val suggestions = content
                .split("\n")
                .map { it.trim() }
                .filter { it.isNotBlank() }
                .take(3)

            Log.d(TAG, "Got suggestions: $suggestions from content: $content")
            Result.success(suggestions)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get suggestions", e)
            Result.failure(e)
        }
    }
}

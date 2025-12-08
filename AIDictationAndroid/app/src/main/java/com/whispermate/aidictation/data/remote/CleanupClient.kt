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

object CleanupClient {
    private const val TAG = "CleanupClient"

    private val okHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .build()
    }

    private val defaultCleanupPrompt = """Clean up the dictated text. Fix grammar, punctuation, capitalization. Remove filler words and stutters. Keep meaning intact. Return ONLY the cleaned text."""

    suspend fun cleanupText(text: String, context: String = "", contextRules: String? = null): Result<String> = withContext(Dispatchers.IO) {
        try {
            val apiKey = BuildConfig.GROQ_API_KEY
            if (apiKey.isEmpty()) {
                return@withContext Result.failure(Exception("Groq API key not configured"))
            }

            if (text.isBlank()) {
                return@withContext Result.success(text)
            }

            // Build system prompt with optional context rules
            val systemPrompt = if (!contextRules.isNullOrEmpty()) {
                "$defaultCleanupPrompt\n\nAdditional instructions: $contextRules"
            } else {
                defaultCleanupPrompt
            }

            val requestJson = JSONObject().apply {
                put("model", BuildConfig.GROQ_MODEL)
                val userContent = if (context.isNotBlank()) {
                    "Context before: \"$context\"\n\nClean up: \"$text\""
                } else {
                    "Clean up: \"$text\""
                }
                put("messages", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "system")
                        put("content", systemPrompt)
                    })
                    put(JSONObject().apply {
                        put("role", "user")
                        put("content", userContent)
                    })
                })
                put("max_tokens", 1000)
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
                Log.e(TAG, "Cleanup request failed: ${response.code} - $errorBody")
                return@withContext Result.failure(Exception("Cleanup request failed: ${response.code}"))
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

            Log.d(TAG, "Cleaned text: $content")
            Result.success(content)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cleanup text", e)
            Result.failure(e)
        }
    }
}

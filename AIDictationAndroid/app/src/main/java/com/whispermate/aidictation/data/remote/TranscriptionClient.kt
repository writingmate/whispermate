package com.whispermate.aidictation.data.remote

import com.whispermate.aidictation.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

object TranscriptionClient {

    private val okHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    suspend fun transcribe(audioFile: File, prompt: String? = null): Result<String> = withContext(Dispatchers.IO) {
        try {
            val apiKey = BuildConfig.TRANSCRIPTION_API_KEY
            if (apiKey.isEmpty()) {
                return@withContext Result.failure(Exception("API key not configured"))
            }

            val requestBody = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart(
                    "file",
                    audioFile.name,
                    audioFile.asRequestBody("audio/m4a".toMediaType())
                )
                .addFormDataPart("model", BuildConfig.TRANSCRIPTION_MODEL)
                .addFormDataPart("temperature", "0")
                .addFormDataPart("response_format", "json")
                .apply {
                    if (!prompt.isNullOrEmpty()) {
                        addFormDataPart("prompt", prompt)
                    }
                }
                .build()

            val request = Request.Builder()
                .url(BuildConfig.TRANSCRIPTION_ENDPOINT)
                .addHeader("Authorization", "Bearer $apiKey")
                .post(requestBody)
                .build()

            val response = okHttpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                val errorBody = response.body?.string() ?: "Unknown error"
                return@withContext Result.failure(Exception("Transcription failed: ${response.code} - $errorBody"))
            }

            val responseBody = response.body?.string()
            val json = JSONObject(responseBody ?: "{}")
            val text = json.optString("text", "").trim()

            Result.success(text)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

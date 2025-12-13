package com.whispermate.aidictation.data.remote

import android.util.Log
import com.whispermate.aidictation.BuildConfig
import com.whispermate.aidictation.domain.model.Command
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

/**
 * Result of transcription that may include command execution.
 * @param text The final text to insert/replace
 * @param executedCommand The command ID if a voice command was detected and executed, null otherwise
 * @param originalTranscription The raw transcription before command processing
 */
data class TranscriptionResult(
    val text: String,
    val executedCommand: String? = null,
    val originalTranscription: String = text
)

object TranscriptionClient {
    private const val TAG = "TranscriptionClient"

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
            Log.d(TAG, "Transcribing file: ${audioFile.absolutePath}, size: ${audioFile.length()} bytes")
            Log.d(TAG, "Endpoint: ${BuildConfig.TRANSCRIPTION_ENDPOINT}")
            Log.d(TAG, "Model: ${BuildConfig.TRANSCRIPTION_MODEL}")

            if (apiKey.isEmpty()) {
                Log.e(TAG, "API key is empty!")
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
                        Log.d(TAG, "Prompt: $prompt")
                    }
                }
                .build()

            val request = Request.Builder()
                .url(BuildConfig.TRANSCRIPTION_ENDPOINT)
                .addHeader("Authorization", "Bearer $apiKey")
                .post(requestBody)
                .build()

            Log.d(TAG, "Sending transcription request...")
            val response = okHttpClient.newCall(request).execute()
            Log.d(TAG, "Response code: ${response.code}")

            if (!response.isSuccessful) {
                val errorBody = response.body?.string() ?: "Unknown error"
                Log.e(TAG, "Transcription failed: ${response.code} - $errorBody")
                return@withContext Result.failure(Exception("Transcription failed: ${response.code} - $errorBody"))
            }

            val responseBody = response.body?.string()
            Log.d(TAG, "Response body: $responseBody")
            val json = JSONObject(responseBody ?: "{}")
            val text = json.optString("text", "").trim()
            Log.d(TAG, "Transcribed text: '$text'")

            Result.success(text)
        } catch (e: Exception) {
            Log.e(TAG, "Transcription exception", e)
            Result.failure(e)
        }
    }

    /**
     * Transcribe audio with voice command detection and execution.
     *
     * @param audioFile The audio file to transcribe
     * @param prompt Optional transcription prompt/context
     * @param contextText Text before cursor (for command execution)
     * @param commands List of enabled commands to detect
     * @param additionalInstructions Optional additional instructions for command execution
     * @return TranscriptionResult with text and optional executed command ID
     */
    suspend fun transcribeWithCommands(
        audioFile: File,
        prompt: String? = null,
        contextText: String = "",
        commands: List<Command>,
        additionalInstructions: String? = null
    ): Result<TranscriptionResult> = withContext(Dispatchers.IO) {
        try {
            // First, transcribe the audio normally
            val transcriptionResult = transcribe(audioFile, prompt)

            transcriptionResult.fold(
                onSuccess = { rawText ->
                    if (rawText.isBlank()) {
                        return@withContext Result.success(TranscriptionResult(rawText))
                    }

                    // Check if the transcription ends with a voice command trigger
                    val detectedCommand = detectCommand(rawText, commands)

                    if (detectedCommand != null) {
                        Log.d(TAG, "Detected voice command: ${detectedCommand.first.name}")

                        // Extract the text before the command trigger
                        val textBeforeCommand = detectedCommand.second.trim()

                        // Combine with context - the command operates on context + text before trigger
                        val targetText = if (textBeforeCommand.isNotEmpty()) {
                            textBeforeCommand
                        } else {
                            // If no text before command, use the context text (last dictation)
                            contextText.trim()
                        }

                        if (targetText.isEmpty()) {
                            // No text to execute command on, return raw transcription
                            Log.d(TAG, "No target text for command, returning raw transcription")
                            return@withContext Result.success(
                                TranscriptionResult(rawText, originalTranscription = rawText)
                            )
                        }

                        // Execute the command
                        val commandResult = CommandClient.execute(
                            command = detectedCommand.first,
                            targetText = targetText,
                            context = if (textBeforeCommand.isNotEmpty()) contextText else "",
                            additionalInstructions = additionalInstructions
                        )

                        commandResult.fold(
                            onSuccess = { transformedText ->
                                Result.success(
                                    TranscriptionResult(
                                        text = transformedText,
                                        executedCommand = detectedCommand.first.id,
                                        originalTranscription = rawText
                                    )
                                )
                            },
                            onFailure = { error ->
                                Log.e(TAG, "Command execution failed", error)
                                // Return raw transcription on command failure
                                Result.success(TranscriptionResult(rawText, originalTranscription = rawText))
                            }
                        )
                    } else {
                        // No command detected, return normal transcription
                        Result.success(TranscriptionResult(rawText, originalTranscription = rawText))
                    }
                },
                onFailure = { error ->
                    Result.failure(error)
                }
            )
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Detect if the transcription ends with a voice command trigger.
     * Returns the matched command and the text before the trigger, or null if no command detected.
     */
    private fun detectCommand(text: String, commands: List<Command>): Pair<Command, String>? {
        val lowerText = text.lowercase().trim()

        for (command in commands) {
            for (trigger in command.voiceTriggers) {
                val lowerTrigger = trigger.lowercase()

                // Check if text ends with the trigger (with some flexibility for punctuation)
                val cleanedText = lowerText.trimEnd('.', ',', '!', '?', ' ')
                if (cleanedText.endsWith(lowerTrigger)) {
                    // Extract text before the trigger
                    val triggerStart = cleanedText.length - lowerTrigger.length
                    val textBefore = text.substring(0, triggerStart).trimEnd('.', ',', '!', '?', ' ')
                    return Pair(command, textBefore)
                }

                // Also check for trigger at the start followed by content (e.g., "rewrite this: ...")
                // Less common but possible pattern
            }
        }

        return null
    }
}

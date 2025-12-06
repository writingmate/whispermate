package com.whispermate.aidictation.data.remote

import com.squareup.moshi.JsonClass
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part

interface TranscriptionApi {
    @Multipart
    @POST("v1/audio/transcriptions")
    suspend fun transcribe(
        @Header("Authorization") authorization: String,
        @Part file: MultipartBody.Part,
        @Part("model") model: RequestBody,
        @Part("temperature") temperature: RequestBody,
        @Part("response_format") responseFormat: RequestBody,
        @Part("prompt") prompt: RequestBody? = null
    ): TranscriptionResponse
}

@JsonClass(generateAdapter = true)
data class TranscriptionResponse(
    val text: String
)

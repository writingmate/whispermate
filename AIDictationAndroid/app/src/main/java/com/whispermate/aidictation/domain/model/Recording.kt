package com.whispermate.aidictation.domain.model

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

data class Recording(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val transcription: String,
    val durationMs: Long? = null,
    val audioFilePath: String? = null
) {
    val formattedDate: String
        get() {
            val instant = Instant.ofEpochMilli(timestamp)
            val formatter = DateTimeFormatter.ofPattern("MMM d, yyyy 'at' h:mm a")
                .withZone(ZoneId.systemDefault())
            return formatter.format(instant)
        }

    val formattedDuration: String?
        get() = durationMs?.let { ms ->
            val seconds = ms / 1000
            val minutes = seconds / 60
            val remainingSeconds = seconds % 60
            "${minutes}:${remainingSeconds.toString().padStart(2, '0')}"
        }
}

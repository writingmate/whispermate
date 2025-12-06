package com.whispermate.aidictation.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.whispermate.aidictation.domain.model.Recording

@Entity(tableName = "recordings")
data class RecordingEntity(
    @PrimaryKey
    val id: String,
    val timestamp: Long,
    val transcription: String,
    val durationMs: Long?,
    val audioFilePath: String?
) {
    fun toDomain(): Recording = Recording(
        id = id,
        timestamp = timestamp,
        transcription = transcription,
        durationMs = durationMs,
        audioFilePath = audioFilePath
    )

    companion object {
        fun fromDomain(recording: Recording): RecordingEntity = RecordingEntity(
            id = recording.id,
            timestamp = recording.timestamp,
            transcription = recording.transcription,
            durationMs = recording.durationMs,
            audioFilePath = recording.audioFilePath
        )
    }
}

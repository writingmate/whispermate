package com.whispermate.aidictation.data.repository

import com.whispermate.aidictation.data.local.dao.RecordingDao
import com.whispermate.aidictation.data.local.entity.RecordingEntity
import com.whispermate.aidictation.domain.model.Recording
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RecordingRepository @Inject constructor(
    private val recordingDao: RecordingDao
) {
    val recordings: Flow<List<Recording>> = recordingDao.getAllRecordings()
        .map { entities -> entities.map { it.toDomain() } }

    suspend fun addRecording(recording: Recording) {
        recordingDao.insertRecording(RecordingEntity.fromDomain(recording))
    }

    suspend fun deleteRecording(recording: Recording) {
        // Delete audio file if exists
        recording.audioFilePath?.let { path ->
            try {
                File(path).delete()
            } catch (_: Exception) { }
        }
        recordingDao.deleteRecording(recording.id)
    }

    suspend fun clearAllRecordings() {
        recordingDao.deleteAllRecordings()
    }

    suspend fun getRecordingById(id: String): Recording? {
        return recordingDao.getRecordingById(id)?.toDomain()
    }
}

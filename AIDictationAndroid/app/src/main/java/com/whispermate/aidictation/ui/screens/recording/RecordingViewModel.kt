package com.whispermate.aidictation.ui.screens.recording

import androidx.lifecycle.ViewModel
import com.whispermate.aidictation.data.repository.TranscriptionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import java.io.File
import javax.inject.Inject

@HiltViewModel
class RecordingViewModel @Inject constructor(
    private val transcriptionRepository: TranscriptionRepository
) : ViewModel() {

    suspend fun transcribe(audioFile: File): Result<String> {
        val prompt = transcriptionRepository.buildPrompt()
        val result = transcriptionRepository.transcribe(audioFile, prompt.ifEmpty { null })

        return result.map { rawText ->
            transcriptionRepository.applyPostProcessing(rawText)
        }
    }
}

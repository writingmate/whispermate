package com.whispermate.aidictation.ui.screens.main

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.whispermate.aidictation.data.repository.RecordingRepository
import com.whispermate.aidictation.data.repository.TranscriptionRepository
import com.whispermate.aidictation.domain.model.Recording
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.io.File
import javax.inject.Inject

enum class RecordingState {
    Idle,
    Recording,
    Processing
}

@HiltViewModel
class MainViewModel @Inject constructor(
    private val recordingRepository: RecordingRepository,
    private val transcriptionRepository: TranscriptionRepository
) : ViewModel() {

    val recordings: StateFlow<List<Recording>> = recordingRepository.recordings
        .stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    // Recording state for inline recording
    private val _recordingState = MutableStateFlow(RecordingState.Idle)
    val recordingState: StateFlow<RecordingState> = _recordingState.asStateFlow()

    // Selected recording for detail view
    private val _selectedRecording = MutableStateFlow<Recording?>(null)
    val selectedRecording: StateFlow<Recording?> = _selectedRecording.asStateFlow()

    // Error state
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    fun startRecording() {
        _recordingState.value = RecordingState.Recording
    }

    fun stopRecording(audioFile: File?, durationMs: Long) {
        if (audioFile == null || durationMs < 300) {
            _recordingState.value = RecordingState.Idle
            return
        }

        _recordingState.value = RecordingState.Processing

        viewModelScope.launch {
            val prompt = transcriptionRepository.buildPrompt()
            val result = transcriptionRepository.transcribe(audioFile, prompt.ifEmpty { null })

            result.fold(
                onSuccess = { rawText ->
                    val processedText = transcriptionRepository.applyPostProcessing(rawText)
                    if (processedText.isNotEmpty()) {
                        val recording = Recording(
                            transcription = processedText,
                            durationMs = durationMs,
                            audioFilePath = audioFile.absolutePath
                        )
                        recordingRepository.addRecording(recording)
                        _selectedRecording.value = recording
                    }
                    _recordingState.value = RecordingState.Idle
                },
                onFailure = { e ->
                    _error.value = e.message ?: "Transcription failed"
                    _recordingState.value = RecordingState.Idle
                }
            )
        }
    }

    fun selectRecording(recording: Recording) {
        _selectedRecording.value = recording
    }

    fun clearSelectedRecording() {
        _selectedRecording.value = null
    }

    fun clearError() {
        _error.value = null
    }

    fun deleteRecording(recording: Recording) {
        viewModelScope.launch {
            recordingRepository.deleteRecording(recording)
            if (_selectedRecording.value?.id == recording.id) {
                _selectedRecording.value = null
            }
        }
    }

    fun clearAllHistory() {
        viewModelScope.launch {
            recordingRepository.clearAllRecordings()
        }
    }
}

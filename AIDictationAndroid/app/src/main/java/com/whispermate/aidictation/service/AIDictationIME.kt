/*
 * Copyright (C) 2024 WhisperMate
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.whispermate.aidictation.service

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Color
import android.inputmethodservice.InputMethodService
import android.util.Log
import android.view.View
import android.view.inputmethod.ExtractedTextRequest
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.whispermate.aidictation.R
import com.whispermate.aidictation.data.remote.SuggestionClient
import com.whispermate.aidictation.data.remote.TranscriptionClient
import com.whispermate.aidictation.util.AudioRecorder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import rkr.simplekeyboard.inputmethod.latin.LatinIME
import rkr.simplekeyboard.inputmethod.latin.common.Constants

/**
 * AI Dictation keyboard extending simple-keyboard's LatinIME.
 * Adds voice input capability via mic button in top toolbar.
 */
class AIDictationIME : LatinIME() {

    companion object {
        private const val TAG = "AIDictationIME"
    }

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var audioRecorder: AudioRecorder? = null
    private var vadJob: Job? = null
    private var suggestionJob: Job? = null
    private var micButton: ImageButton? = null
    private var toolbarView: View? = null
    private var suggestion1: TextView? = null
    private var suggestion2: TextView? = null
    private var suggestion3: TextView? = null
    private var divider1: View? = null
    private var divider2: View? = null
    private var lastText: String = ""

    private val _recordingState = MutableStateFlow(RecordingState.Idle)

    enum class RecordingState {
        Idle, Recording, Processing
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AIDictationIME created")
    }

    override fun onCreateInputView(): View {
        Log.d(TAG, "onCreateInputView called")

        // Inflate our container with toolbar
        val container = layoutInflater.inflate(R.layout.keyboard_container, null)

        // Get the original keyboard from parent
        val originalKeyboard = super.onCreateInputView()

        // Add keyboard to our container
        val keyboardFrame = container.findViewById<FrameLayout>(R.id.keyboard_frame)
        keyboardFrame.addView(originalKeyboard)

        // Set up mic button
        micButton = container.findViewById<ImageButton>(R.id.mic_button)?.apply {
            setOnClickListener { toggleVoiceInput() }
        }

        // Set up suggestion buttons
        suggestion1 = container.findViewById<TextView>(R.id.suggestion_1)?.apply {
            setOnClickListener { insertSuggestion(text.toString()) }
        }
        suggestion2 = container.findViewById<TextView>(R.id.suggestion_2)?.apply {
            setOnClickListener { insertSuggestion(text.toString()) }
        }
        suggestion3 = container.findViewById<TextView>(R.id.suggestion_3)?.apply {
            setOnClickListener { insertSuggestion(text.toString()) }
        }
        divider1 = container.findViewById(R.id.divider_1)
        divider2 = container.findViewById(R.id.divider_2)

        // Store reference to toolbar for insets calculation
        toolbarView = container.findViewById<LinearLayout>(R.id.keyboard_toolbar)

        Log.d(TAG, "Container created with toolbar, micButton: $micButton")

        return container
    }

    private fun insertSuggestion(suggestion: String) {
        if (suggestion.isBlank()) return

        val ic = currentInputConnection ?: return

        // Get text before cursor to check if we need a space
        val textBefore = ic.getTextBeforeCursor(1, 0)?.toString() ?: ""
        val needsSpace = textBefore.isNotEmpty() && !textBefore.endsWith(" ")

        // Check if the suggestion completes a partial word
        val extracted = ic.getExtractedText(ExtractedTextRequest(), 0)
        val fullText = extracted?.text?.toString() ?: ""
        val cursorPos = extracted?.selectionStart ?: 0

        // Find the start of the current word
        var wordStart = cursorPos - 1
        while (wordStart >= 0 && fullText[wordStart] != ' ') {
            wordStart--
        }
        wordStart++

        val currentWord = if (wordStart < cursorPos) fullText.substring(wordStart, cursorPos) else ""

        if (currentWord.isNotEmpty() && suggestion.startsWith(currentWord, ignoreCase = true)) {
            // Complete the word - delete current partial and insert full suggestion
            ic.deleteSurroundingText(currentWord.length, 0)
            ic.commitText("$suggestion ", 1)
        } else {
            // Insert as next word
            val prefix = if (needsSpace) " " else ""
            ic.commitText("$prefix$suggestion ", 1)
        }

        // Refresh suggestions
        requestSuggestions()
    }

    override fun onComputeInsets(outInsets: InputMethodService.Insets) {
        super.onComputeInsets(outInsets)

        // Extend touchable region to include toolbar
        val toolbar = toolbarView ?: return
        val toolbarHeight = toolbar.height
        if (toolbarHeight > 0) {
            // Adjust the touchable region to include the toolbar
            val rect = outInsets.touchableRegion.bounds
            outInsets.touchableRegion.set(rect.left, rect.top - toolbarHeight, rect.right, rect.bottom)
            outInsets.contentTopInsets -= toolbarHeight
            outInsets.visibleTopInsets -= toolbarHeight
        }
    }

    override fun onDestroy() {
        scope.cancel()
        audioRecorder?.release()
        super.onDestroy()
    }

    private fun updateMicButtonState() {
        micButton?.let { btn ->
            when (_recordingState.value) {
                RecordingState.Idle -> {
                    btn.setColorFilter(null)
                    btn.alpha = 1.0f
                }
                RecordingState.Recording -> {
                    btn.setColorFilter(Color.RED)
                    btn.alpha = 1.0f
                }
                RecordingState.Processing -> {
                    btn.setColorFilter(Color.GRAY)
                    btn.alpha = 0.5f
                }
            }
        }
    }

    override fun onCodeInput(primaryCode: Int, x: Int, y: Int, isKeyRepeat: Boolean) {
        if (primaryCode == Constants.CODE_VOICE_INPUT) {
            toggleVoiceInput()
        } else {
            super.onCodeInput(primaryCode, x, y, isKeyRepeat)
            // Trigger suggestions after keystroke with debounce
            requestSuggestionsDebounced()
        }
    }

    private fun requestSuggestionsDebounced() {
        suggestionJob?.cancel()
        suggestionJob = scope.launch {
            delay(300) // Debounce 300ms
            requestSuggestions()
        }
    }

    private fun requestSuggestions() {
        val ic = currentInputConnection ?: return
        val extracted = ic.getExtractedText(ExtractedTextRequest(), 0) ?: return
        val text = extracted.text?.toString() ?: ""
        val cursorPos = extracted.selectionStart

        // Get text up to cursor
        val textBeforeCursor = if (cursorPos > 0 && cursorPos <= text.length) {
            text.substring(0, cursorPos)
        } else {
            text
        }

        // Skip if text hasn't changed
        if (textBeforeCursor == lastText) return
        lastText = textBeforeCursor

        // Skip if empty
        if (textBeforeCursor.isEmpty()) {
            clearSuggestions()
            return
        }

        // Determine mode: completing current word or suggesting next word
        val isCompletingWord = textBeforeCursor.isNotEmpty() && !textBeforeCursor.endsWith(" ")

        scope.launch {
            try {
                val result = SuggestionClient.getSuggestions(textBeforeCursor, isCompletingWord)
                result.onSuccess { suggestions ->
                    updateSuggestions(suggestions)
                }.onFailure {
                    Log.e(TAG, "Failed to get suggestions", it)
                    clearSuggestions()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error getting suggestions", e)
                clearSuggestions()
            }
        }
    }

    private fun updateSuggestions(suggestions: List<String>) {
        val hasSuggestions = suggestions.isNotEmpty()
        // Extract just the first word from each suggestion
        val s1 = suggestions.getOrNull(0)?.split(" ")?.firstOrNull() ?: ""
        val s2 = suggestions.getOrNull(1)?.split(" ")?.firstOrNull() ?: ""
        val s3 = suggestions.getOrNull(2)?.split(" ")?.firstOrNull() ?: ""

        suggestion1?.text = s1
        suggestion2?.text = s2
        suggestion3?.text = s3

        // Show dividers only when there are suggestions
        divider1?.visibility = if (hasSuggestions && s1.isNotEmpty() && s2.isNotEmpty()) View.VISIBLE else View.GONE
        divider2?.visibility = if (hasSuggestions && s2.isNotEmpty() && s3.isNotEmpty()) View.VISIBLE else View.GONE
    }

    private fun clearSuggestions() {
        suggestion1?.text = ""
        suggestion2?.text = ""
        suggestion3?.text = ""
        divider1?.visibility = View.GONE
        divider2?.visibility = View.GONE
    }

    private fun toggleVoiceInput() {
        when (_recordingState.value) {
            RecordingState.Idle -> startRecording()
            RecordingState.Recording -> stopRecording()
            RecordingState.Processing -> { /* ignore while processing */ }
        }
    }

    private fun startRecording() {
        // Check permission
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            Toast.makeText(this, "Microphone permission required", Toast.LENGTH_SHORT).show()
            return
        }

        Log.d(TAG, "Starting voice recording")
        _recordingState.value = RecordingState.Recording
        updateMicButtonState()

        val recorder = AudioRecorder(this, enableVAD = true)
        audioRecorder = recorder

        val file = recorder.start()
        if (file == null) {
            Log.e(TAG, "Failed to start recording")
            _recordingState.value = RecordingState.Idle
            updateMicButtonState()
            audioRecorder = null
            return
        }

        // Listen for VAD auto-stop
        vadJob = scope.launch {
            recorder.shouldAutoStop.collectLatest { shouldStop ->
                if (shouldStop && _recordingState.value == RecordingState.Recording) {
                    Log.d(TAG, "VAD triggered auto-stop")
                    stopRecording()
                }
            }
        }
    }

    private fun stopRecording() {
        Log.d(TAG, "Stopping voice recording")
        vadJob?.cancel()
        vadJob = null

        val recorder = audioRecorder ?: return
        _recordingState.value = RecordingState.Processing
        updateMicButtonState()

        val result = recorder.stop()
        val audioFile = result?.first
        val duration = result?.second ?: 0L

        audioRecorder = null

        if (audioFile == null || !audioFile.exists()) {
            Log.e(TAG, "No audio file recorded")
            _recordingState.value = RecordingState.Idle
            updateMicButtonState()
            return
        }

        // Skip very short recordings (less than 500ms)
        if (duration < 500) {
            Log.d(TAG, "Recording too short: ${duration}ms")
            audioFile.delete()
            _recordingState.value = RecordingState.Idle
            updateMicButtonState()
            return
        }

        // Transcribe the audio
        scope.launch {
            try {
                val transcriptionResult = TranscriptionClient.transcribe(audioFile)
                transcriptionResult.onSuccess { text ->
                    if (text.isNotBlank()) {
                        Log.d(TAG, "Transcription: $text")
                        currentInputConnection?.commitText(text, 1)
                    }
                }.onFailure { error ->
                    Log.e(TAG, "Transcription failed", error)
                    Toast.makeText(this@AIDictationIME, "Transcription failed: ${error.message}", Toast.LENGTH_SHORT).show()
                }
            } finally {
                audioFile.delete()
                _recordingState.value = RecordingState.Idle
                updateMicButtonState()
            }
        }
    }
}

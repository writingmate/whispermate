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
import android.content.Intent
import android.content.pm.PackageManager
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
import com.squareup.moshi.Moshi
import com.whispermate.aidictation.R
import com.whispermate.aidictation.data.preferences.AppPreferences
import com.whispermate.aidictation.data.remote.CommandClient
import com.whispermate.aidictation.data.remote.SuggestionClient
import com.whispermate.aidictation.data.remote.TranscriptionClient
import com.whispermate.aidictation.domain.model.Command
import com.whispermate.aidictation.ui.views.CircularMicButtonView
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
    private lateinit var appPreferences: AppPreferences
    private var audioRecorder: AudioRecorder? = null
    private var vadJob: Job? = null
    private var audioLevelJob: Job? = null
    private var suggestionJob: Job? = null
    private var settingsButton: ImageButton? = null
    private var micButton: CircularMicButtonView? = null
    private var commandButton: ImageButton? = null
    private var commandMicButton: ImageButton? = null
    private var toolbarView: View? = null
    private var commandActionBar: View? = null
    private var commandRollbackButton: ImageButton? = null
    private var commandAcceptButton: ImageButton? = null
    private var commandStatusText: TextView? = null
    private var suggestion1: TextView? = null
    private var suggestion2: TextView? = null
    private var suggestion3: TextView? = null
    private var divider1: View? = null
    private var divider2: View? = null
    private var lastText: String = ""

    // Command state
    private var lastDictatedText: String = ""
    private var originalTextBeforeCommand: String = ""
    private var transformedText: String = ""
    private var isInCommandReview: Boolean = false
    private var currentCommand: Command? = null

    private val _recordingState = MutableStateFlow(RecordingState.Idle)
    private var recordingMode: RecordingMode = RecordingMode.Dictation

    enum class RecordingState {
        Idle, Recording, Processing
    }

    enum class RecordingMode {
        Dictation,  // Normal voice-to-text
        Command     // Recording a voice command to apply to lastDictatedText
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AIDictationIME created")

        // Initialize AppPreferences manually (not using Hilt in InputMethodService)
        appPreferences = AppPreferences(this, Moshi.Builder().build())
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

        // Set up settings button
        settingsButton = container.findViewById<ImageButton>(R.id.settings_button)?.apply {
            setOnClickListener { openApp() }
        }

        // Set up mic button
        micButton = container.findViewById<CircularMicButtonView>(R.id.mic_button)?.apply {
            setOnClickCallback { toggleVoiceInput() }
        }

        // Set up command mic button (for voice instructions)
        commandMicButton = container.findViewById<ImageButton>(R.id.command_mic_button)?.apply {
            setOnClickListener { startCommandRecording() }
        }

        // Set up command button (cleanup by default)
        commandButton = container.findViewById<ImageButton>(R.id.cleanup_button)?.apply {
            setOnClickListener { executeDefaultCommand() }
        }

        // Set up command action bar (reused for all commands)
        commandActionBar = container.findViewById(R.id.cleanup_action_bar)
        commandStatusText = container.findViewById(R.id.cleanup_status_text)
        commandRollbackButton = container.findViewById<ImageButton>(R.id.cleanup_rollback_button)?.apply {
            setOnClickListener { rollbackCommand() }
        }
        commandAcceptButton = container.findViewById<ImageButton>(R.id.cleanup_accept_button)?.apply {
            setOnClickListener { acceptCommand() }
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

        // Get text before cursor to find the current partial word
        val textBefore = ic.getTextBeforeCursor(50, 0)?.toString() ?: ""

        // Find the start of the current word by looking for word boundaries
        var wordStartIndex = textBefore.length - 1
        while (wordStartIndex >= 0 && textBefore[wordStartIndex].isLetterOrDigit()) {
            wordStartIndex--
        }
        wordStartIndex++

        val currentWord = if (wordStartIndex < textBefore.length) {
            textBefore.substring(wordStartIndex)
        } else {
            ""
        }

        // Always delete the current partial word and replace with the suggestion
        if (currentWord.isNotEmpty()) {
            ic.deleteSurroundingText(currentWord.length, 0)
            ic.commitText("$suggestion ", 1)
        } else {
            // No partial word, insert as next word with space if needed
            val needsSpace = textBefore.isNotEmpty() && !textBefore.last().isWhitespace()
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

    override fun onUpdateSelection(
        oldSelStart: Int, oldSelEnd: Int,
        newSelStart: Int, newSelEnd: Int,
        candidatesStart: Int, candidatesEnd: Int
    ) {
        super.onUpdateSelection(oldSelStart, oldSelEnd, newSelStart, newSelEnd, candidatesStart, candidatesEnd)

        // Update command buttons based on selection
        updateCommandButtonsForSelection()
    }

    private fun updateMicButtonState() {
        micButton?.setState(
            when (_recordingState.value) {
                RecordingState.Idle -> CircularMicButtonView.State.Idle
                RecordingState.Recording -> CircularMicButtonView.State.Recording
                RecordingState.Processing -> CircularMicButtonView.State.Processing
            }
        )
    }

    override fun onCodeInput(primaryCode: Int, x: Int, y: Int, isKeyRepeat: Boolean) {
        if (primaryCode == Constants.CODE_VOICE_INPUT) {
            toggleVoiceInput()
        } else {
            // Clear command review state when user makes any input
            if (isInCommandReview) {
                clearCommandState()
            }
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

    private fun openApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
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

        // Listen for audio levels and frequency bands to animate the mic button
        audioLevelJob = scope.launch {
            launch {
                recorder.audioLevel.collectLatest { level ->
                    micButton?.setAudioLevel(level)
                }
            }
            launch {
                recorder.frequencyBands.collectLatest { bands ->
                    micButton?.setFrequencyBands(bands)
                }
            }
        }
    }

    private fun stopRecording() {
        Log.d(TAG, "Stopping voice recording, mode: $recordingMode")
        vadJob?.cancel()
        vadJob = null
        audioLevelJob?.cancel()
        audioLevelJob = null

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
            recordingMode = RecordingMode.Dictation
            return
        }

        // Skip very short recordings (less than 500ms)
        if (duration < 500) {
            Log.d(TAG, "Recording too short: ${duration}ms")
            audioFile.delete()
            _recordingState.value = RecordingState.Idle
            updateMicButtonState()
            recordingMode = RecordingMode.Dictation
            return
        }

        // Get context for transcription (last ~200 chars before cursor)
        val ic = currentInputConnection
        val contextText = ic?.getTextBeforeCursor(200, 0)?.toString()?.takeLast(200) ?: ""

        // Get current app's package name for context rules
        val currentPackage = currentInputEditorInfo?.packageName

        // Capture recording mode before async work
        val currentRecordingMode = recordingMode
        recordingMode = RecordingMode.Dictation // Reset for next recording

        // Handle based on recording mode
        scope.launch {
            try {
                when (currentRecordingMode) {
                    RecordingMode.Command -> {
                        // Command mode: transcribe instruction and execute on lastDictatedText
                        handleCommandRecording(audioFile, currentPackage)
                    }
                    RecordingMode.Dictation -> {
                        // Normal dictation mode
                        handleDictationRecording(audioFile, contextText, currentPackage, ic)
                    }
                }
            } finally {
                audioFile.delete()
                _recordingState.value = RecordingState.Idle
                updateMicButtonState()
            }
        }
    }

    /**
     * Handle command recording: transcribe the instruction and apply it to lastDictatedText.
     */
    private suspend fun handleCommandRecording(audioFile: java.io.File, currentPackage: String?) {
        val ic = currentInputConnection ?: return

        // Simple transcription of the instruction
        val transcriptionResult = TranscriptionClient.transcribe(audioFile, null)

        transcriptionResult.onSuccess { instruction ->
            if (instruction.isBlank()) {
                Toast.makeText(this@AIDictationIME, "No instruction heard", Toast.LENGTH_SHORT).show()
                return@onSuccess
            }

            Log.d(TAG, "Voice instruction: $instruction")

            // Get full text and determine target (selected text or last dictated)
            val extracted = ic.getExtractedText(ExtractedTextRequest(), 0) ?: return@onSuccess
            val fullText = extracted.text?.toString() ?: ""
            val selStart = extracted.selectionStart
            val selEnd = extracted.selectionEnd

            val targetText: String
            val targetStart: Int
            val targetEnd: Int

            if (selStart != selEnd && selStart >= 0 && selEnd >= 0 && selEnd <= fullText.length) {
                // Use selected text
                targetText = fullText.substring(selStart, selEnd)
                targetStart = selStart
                targetEnd = selEnd
            } else if (lastDictatedText.isNotBlank()) {
                // Use last dictated text
                targetText = lastDictatedText
                val idx = fullText.lastIndexOf(lastDictatedText)
                if (idx < 0) {
                    Toast.makeText(this@AIDictationIME, "Cannot find text to transform", Toast.LENGTH_SHORT).show()
                    return@onSuccess
                }
                targetStart = idx
                targetEnd = idx + lastDictatedText.length
            } else {
                Toast.makeText(this@AIDictationIME, "No text to transform", Toast.LENGTH_SHORT).show()
                return@onSuccess
            }

            // Store original for rollback
            originalTextBeforeCommand = fullText
            currentCommand = null // Free-form instruction, not a predefined command

            // Get context (text before the target)
            val context = if (targetStart > 0) fullText.substring(0, targetStart).takeLast(200) else ""

            // Show processing state
            commandStatusText?.text = "Processing..."
            showCommandActionBar()

            // Get context rules
            val contextRules = appPreferences.getInstructionsForApp(currentPackage)

            // Execute the instruction
            val commandResult = CommandClient.executeInstruction(
                instruction = instruction,
                targetText = targetText,
                context = context,
                additionalInstructions = contextRules
            )

            commandResult.onSuccess { transformed ->
                transformedText = transformed

                // Replace the target text with transformed version
                val newText = fullText.substring(0, targetStart) + transformed +
                    fullText.substring(targetEnd)
                ic.deleteSurroundingText(fullText.length, 0)
                ic.commitText(newText, 1)

                commandStatusText?.text = "Review changes"
                isInCommandReview = true
            }.onFailure { error ->
                Log.e(TAG, "Command execution failed", error)
                Toast.makeText(this@AIDictationIME, "Command failed: ${error.message}", Toast.LENGTH_SHORT).show()
                hideCommandActionBar()
            }
        }.onFailure { error ->
            Log.e(TAG, "Transcription failed", error)
            Toast.makeText(this@AIDictationIME, "Transcription failed: ${error.message}", Toast.LENGTH_SHORT).show()
        }
    }

    /**
     * Handle normal dictation recording with voice command detection.
     */
    private suspend fun handleDictationRecording(
        audioFile: java.io.File,
        contextText: String,
        currentPackage: String?,
        ic: android.view.inputmethod.InputConnection?
    ) {
        // Get context rules for the current app
        val contextRules = appPreferences.getInstructionsForApp(currentPackage)

        // Get enabled commands for voice detection
        val enabledCommands = appPreferences.getEnabledCommands()

        // Build transcription prompt with context and rules
        val transcriptionPrompt = buildString {
            if (contextText.isNotEmpty()) {
                append(contextText)
            }
            if (!contextRules.isNullOrEmpty()) {
                if (isNotEmpty()) append("\n\n")
                append("Instructions: ")
                append(contextRules)
            }
        }.ifEmpty { null }

        // Use transcribeWithCommands for voice command detection
        val result = TranscriptionClient.transcribeWithCommands(
            audioFile = audioFile,
            prompt = transcriptionPrompt,
            contextText = lastDictatedText, // Use last dictation as context for commands
            commands = enabledCommands,
            additionalInstructions = contextRules
        )

        result.onSuccess { transcriptionResult ->
            if (transcriptionResult.executedCommand != null) {
                // Voice command was detected and executed
                Log.d(TAG, "Voice command executed: ${transcriptionResult.executedCommand}")

                // Find the command to get its name
                val command = enabledCommands.find { it.id == transcriptionResult.executedCommand }
                currentCommand = command

                // Store original for rollback
                val extracted = ic?.getExtractedText(ExtractedTextRequest(), 0)
                originalTextBeforeCommand = extracted?.text?.toString() ?: ""

                // Replace last dictated text with the transformed result
                if (lastDictatedText.isNotBlank()) {
                    val dictatedStart = originalTextBeforeCommand.lastIndexOf(lastDictatedText)
                    if (dictatedStart >= 0) {
                        val newText = originalTextBeforeCommand.substring(0, dictatedStart) +
                            transcriptionResult.text +
                            originalTextBeforeCommand.substring(dictatedStart + lastDictatedText.length)
                        ic?.deleteSurroundingText(originalTextBeforeCommand.length, 0)
                        ic?.commitText(newText, 1)
                    } else {
                        // Just append if we can't find the original
                        currentInputConnection?.commitText(transcriptionResult.text, 1)
                    }
                } else {
                    // No previous dictation, just insert the result
                    currentInputConnection?.commitText(transcriptionResult.text, 1)
                }

                transformedText = transcriptionResult.text
                isInCommandReview = true
                commandStatusText?.text = "Review ${command?.name ?: "command"}"
                showCommandActionBar()
            } else {
                // Normal transcription
                val text = transcriptionResult.text
                if (text.isNotBlank()) {
                    Log.d(TAG, "Transcription: $text")
                    currentInputConnection?.commitText(text, 1)
                    // Store dictated text and show command button
                    lastDictatedText = text
                    showCommandButton()
                }
            }
        }.onFailure { error ->
            Log.e(TAG, "Transcription failed", error)
            Toast.makeText(this@AIDictationIME, "Transcription failed: ${error.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun showCommandButton() {
        // Only show command buttons if there's text to transform
        if (lastDictatedText.isBlank()) return

        commandButton?.visibility = View.VISIBLE
        commandMicButton?.visibility = View.VISIBLE
    }

    /**
     * Check if there's selected text and show command buttons if so.
     */
    private fun updateCommandButtonsForSelection() {
        val ic = currentInputConnection ?: return
        val extracted = ic.getExtractedText(ExtractedTextRequest(), 0) ?: return

        val selStart = extracted.selectionStart
        val selEnd = extracted.selectionEnd

        if (selStart != selEnd && selStart >= 0 && selEnd >= 0) {
            // Text is selected - show command buttons
            commandButton?.visibility = View.VISIBLE
            commandMicButton?.visibility = View.VISIBLE
        } else if (lastDictatedText.isBlank()) {
            // No selection and no last dictation - hide buttons
            commandButton?.visibility = View.GONE
            commandMicButton?.visibility = View.GONE
        }
    }

    private fun hideCommandButton() {
        commandButton?.visibility = View.GONE
        commandMicButton?.visibility = View.GONE
        lastDictatedText = ""
    }

    /**
     * Start recording a voice command to apply to the last dictated or selected text.
     */
    private fun startCommandRecording() {
        // Check if there's selected text or last dictated text
        val ic = currentInputConnection
        val extracted = ic?.getExtractedText(ExtractedTextRequest(), 0)
        val selStart = extracted?.selectionStart ?: -1
        val selEnd = extracted?.selectionEnd ?: -1
        val hasSelection = selStart != selEnd && selStart >= 0 && selEnd >= 0

        if (!hasSelection && lastDictatedText.isBlank()) {
            Toast.makeText(this, "No text to transform", Toast.LENGTH_SHORT).show()
            return
        }

        recordingMode = RecordingMode.Command
        startRecording()
    }

    /**
     * Execute the default command (cleanup) when the button is pressed.
     */
    private fun executeDefaultCommand() {
        // Get the cleanup command (or first toolbar command)
        scope.launch {
            val toolbarCommands = appPreferences.getToolbarCommands()
            val cleanupCommand = toolbarCommands.find { it.id == "cleanup" }
                ?: toolbarCommands.firstOrNull()

            if (cleanupCommand != null) {
                executeCommand(cleanupCommand)
            } else {
                Toast.makeText(this@AIDictationIME, "No commands available", Toast.LENGTH_SHORT).show()
            }
        }
    }

    /**
     * Execute a command on the target text (selected or last dictated).
     */
    private fun executeCommand(command: Command) {
        // Get target text: selected text first, then last dictated
        val ic = currentInputConnection ?: return
        val extracted = ic.getExtractedText(ExtractedTextRequest(), 0) ?: return
        val fullText = extracted.text?.toString() ?: ""

        // Check for selected text
        val selStart = extracted.selectionStart
        val selEnd = extracted.selectionEnd
        val targetText: String
        val targetStart: Int
        val targetEnd: Int

        if (selStart != selEnd && selStart >= 0 && selEnd >= 0 && selEnd <= fullText.length) {
            // Use selected text
            targetText = fullText.substring(selStart, selEnd)
            targetStart = selStart
            targetEnd = selEnd
        } else if (lastDictatedText.isNotBlank()) {
            // Use last dictated text
            targetText = lastDictatedText
            val idx = fullText.lastIndexOf(lastDictatedText)
            if (idx < 0) {
                Toast.makeText(this@AIDictationIME, "No text to transform", Toast.LENGTH_SHORT).show()
                return
            }
            targetStart = idx
            targetEnd = idx + lastDictatedText.length
        } else {
            Toast.makeText(this@AIDictationIME, "No text to transform", Toast.LENGTH_SHORT).show()
            return
        }

        // Store original state for rollback
        originalTextBeforeCommand = fullText
        currentCommand = command

        // Get context (text before the target)
        val context = if (targetStart > 0) fullText.substring(0, targetStart).takeLast(200) else ""

        // Get current app's package name for context rules
        val currentPackage = currentInputEditorInfo?.packageName

        // Show processing state
        commandStatusText?.text = "${command.name}..."
        showCommandActionBar()

        scope.launch {
            // Get context rules for command execution
            val contextRules = appPreferences.getInstructionsForApp(currentPackage)
            val result = CommandClient.execute(command, targetText, context, contextRules)

            result.onSuccess { transformed ->
                transformedText = transformed

                // Replace the target text with transformed version
                val newText = fullText.substring(0, targetStart) + transformed +
                    fullText.substring(targetEnd)
                ic.deleteSurroundingText(fullText.length, 0)
                ic.commitText(newText, 1)

                commandStatusText?.text = "Review ${command.name}"
                isInCommandReview = true
            }.onFailure { error ->
                Log.e(TAG, "Command '${command.name}' failed", error)
                Toast.makeText(this@AIDictationIME, "${command.name} failed", Toast.LENGTH_SHORT).show()
                hideCommandActionBar()
            }
        }
    }

    private fun showCommandActionBar() {
        toolbarView?.visibility = View.GONE
        commandActionBar?.visibility = View.VISIBLE
    }

    private fun hideCommandActionBar() {
        commandActionBar?.visibility = View.GONE
        toolbarView?.visibility = View.VISIBLE
        isInCommandReview = false
    }

    private fun clearCommandState() {
        // User made input changes, so exit command review mode
        hideCommandActionBar()
        hideCommandButton()
        transformedText = ""
        originalTextBeforeCommand = ""
        lastDictatedText = ""
        currentCommand = null
    }

    private fun acceptCommand() {
        // Keep the transformed text, just hide the action bar
        hideCommandActionBar()
        hideCommandButton()
        transformedText = ""
        originalTextBeforeCommand = ""
        currentCommand = null
    }

    private fun rollbackCommand() {
        // Restore original text
        val ic = currentInputConnection ?: return
        val extracted = ic.getExtractedText(ExtractedTextRequest(), 0)
        val currentLength = extracted?.text?.length ?: 0

        ic.deleteSurroundingText(currentLength, 0)
        ic.commitText(originalTextBeforeCommand, 1)

        hideCommandActionBar()
        // Keep command button visible for retry
        transformedText = ""
        originalTextBeforeCommand = ""
        currentCommand = null
    }
}

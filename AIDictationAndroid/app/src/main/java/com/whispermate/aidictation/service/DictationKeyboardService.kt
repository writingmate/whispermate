package com.whispermate.aidictation.service

import android.Manifest
import android.content.pm.PackageManager
import android.inputmethodservice.InputMethodService
import android.view.View
import android.view.inputmethod.EditorInfo
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Backspace
import androidx.compose.material.icons.automirrored.filled.KeyboardReturn
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.whispermate.aidictation.data.preferences.AppPreferences
import com.whispermate.aidictation.data.remote.TranscriptionClient
import com.whispermate.aidictation.ui.components.CircularMicButton
import com.squareup.moshi.Moshi
import kotlinx.coroutines.runBlocking
import com.whispermate.aidictation.ui.components.MicButtonState
import com.whispermate.aidictation.ui.theme.AIDictationTheme
import com.whispermate.aidictation.util.AudioRecorder
import kotlinx.coroutines.launch
import java.io.File

// iOS Orange color
private val iOSOrange = Color(0xFFFF9500)

class DictationKeyboardService : InputMethodService(), LifecycleOwner, SavedStateRegistryOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateRegistryController = SavedStateRegistryController.create(this)
    private var enterKeyType = androidx.compose.runtime.mutableStateOf(EnterKeyType.Send)
    private var currentAppPackage = mutableStateOf<String?>(null)

    // Lazy init AppPreferences since we can't use Hilt in InputMethodService
    private val appPreferences by lazy {
        AppPreferences(applicationContext, Moshi.Builder().build())
    }

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry get() = savedStateRegistryController.savedStateRegistry

    override fun onCreate() {
        super.onCreate()
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    override fun onCreateInputView(): View {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)

        val composeView = ComposeView(this).apply {
            setContent {
                AIDictationTheme {
                    DictationKeyboard(
                        onTextInput = { text -> commitText(text) },
                        onBackspace = { deleteLastChar() },
                        onEnter = { performEnter() },
                        onSwitchKeyboard = { switchKeyboard() },
                        onOpenSettings = { openSettingsApp() },
                        transcribe = { file -> transcribeAudio(file) },
                        hasMicPermission = hasMicrophonePermission(),
                        enterKeyType = enterKeyType.value
                    )
                }
            }
        }

        // Set view tree owners on the window's decor view for proper Compose lifecycle
        window?.window?.decorView?.let { decorView ->
            decorView.setViewTreeLifecycleOwner(this)
            decorView.setViewTreeSavedStateRegistryOwner(this)
        }

        return composeView
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)

        // Determine enter key type based on editor info
        enterKeyType.value = determineEnterKeyType(info)

        // Capture current app's package name for context rules
        currentAppPackage.value = info?.packageName
    }

    private fun determineEnterKeyType(info: EditorInfo?): EnterKeyType {
        if (info == null) return EnterKeyType.Send

        val imeOptions = info.imeOptions
        val actionId = imeOptions and EditorInfo.IME_MASK_ACTION
        val inputType = info.inputType
        val isMultiLine = (inputType and android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE) != 0

        // If it's a multi-line field with no specific action, use newline
        return if (isMultiLine && (actionId == EditorInfo.IME_ACTION_NONE ||
                                    actionId == EditorInfo.IME_ACTION_UNSPECIFIED)) {
            EnterKeyType.NewLine
        } else {
            EnterKeyType.Send
        }
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        super.onFinishInputView(finishingInput)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    }

    override fun onDestroy() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        super.onDestroy()
    }

    private fun commitText(text: String) {
        currentInputConnection?.commitText(text, 1)
    }

    private fun deleteLastChar() {
        val ic = currentInputConnection ?: return

        // Check if there's selected text
        val selectedText = ic.getSelectedText(0)
        if (selectedText != null && selectedText.isNotEmpty()) {
            // Delete the selected text by committing empty string
            ic.commitText("", 1)
        } else {
            // No selection, delete one character before cursor
            ic.deleteSurroundingText(1, 0)
        }
    }

    private fun performEnter() {
        when (enterKeyType.value) {
            EnterKeyType.NewLine -> {
                currentInputConnection?.commitText("\n", 1)
            }
            EnterKeyType.Send -> {
                val editorInfo = currentInputEditorInfo
                val imeOptions = editorInfo?.imeOptions ?: 0
                val actionId = imeOptions and EditorInfo.IME_MASK_ACTION

                val action = if (actionId != EditorInfo.IME_ACTION_NONE &&
                    actionId != EditorInfo.IME_ACTION_UNSPECIFIED) {
                    actionId
                } else {
                    EditorInfo.IME_ACTION_DONE
                }
                currentInputConnection?.performEditorAction(action)
            }
        }
    }

    private fun switchKeyboard() {
        switchToPreviousInputMethod()
    }

    private fun openSettingsApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun hasMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private suspend fun transcribeAudio(audioFile: File): Result<String> {
        // Get context rules instructions for the current app
        val prompt = appPreferences.getInstructionsForApp(currentAppPackage.value)
        return TranscriptionClient.transcribe(audioFile, prompt)
    }
}

enum class KeyboardState {
    Idle,
    Recording,
    Processing
}

enum class EnterKeyType {
    Send,       // IME_ACTION_SEND, GO, SEARCH, DONE
    NewLine     // Multi-line text field
}

@Composable
private fun DictationKeyboard(
    onTextInput: (String) -> Unit,
    onBackspace: () -> Unit,
    onEnter: () -> Unit,
    onSwitchKeyboard: () -> Unit,
    onOpenSettings: () -> Unit,
    transcribe: suspend (File) -> Result<String>,
    hasMicPermission: Boolean,
    enterKeyType: EnterKeyType = EnterKeyType.Send
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf(KeyboardState.Idle) }
    var audioRecorder by remember { mutableStateOf<AudioRecorder?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val audioLevel = audioRecorder?.audioLevel?.collectAsState()?.value ?: 0f
    val frequencyBands = audioRecorder?.frequencyBands?.collectAsState()?.value
    val shouldAutoStop = audioRecorder?.shouldAutoStop?.collectAsState()?.value ?: false

    // Auto-stop when VAD detects silence after speech
    androidx.compose.runtime.LaunchedEffect(shouldAutoStop) {
        if (shouldAutoStop && state == KeyboardState.Recording) {
            val result = audioRecorder?.stop()
            audioRecorder = null

            if (result != null && result.first != null && result.second >= 300) {
                state = KeyboardState.Processing
                val transcribeResult = transcribe(result.first!!)
                transcribeResult.fold(
                    onSuccess = { text ->
                        if (text.isNotEmpty()) {
                            onTextInput(text)
                        }
                        state = KeyboardState.Idle
                    },
                    onFailure = { e ->
                        errorMessage = e.message ?: "Transcription failed"
                        state = KeyboardState.Idle
                    }
                )
            } else {
                state = KeyboardState.Idle
            }
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            audioRecorder?.release()
        }
    }

    // Fixed height keyboard - 220dp (standard compact keyboard height)
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(220.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 2.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 8.dp, vertical = 8.dp)
        ) {
            // Top bar: Switch keyboard, Settings, Error message
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(40.dp),
                horizontalArrangement = Arrangement.Start,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onSwitchKeyboard, modifier = Modifier.size(40.dp)) {
                    Icon(
                        imageVector = Icons.Default.Keyboard,
                        contentDescription = "Switch keyboard",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onOpenSettings, modifier = Modifier.size(40.dp)) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Settings",
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                // Error message
                errorMessage?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(start = 8.dp)
                    )
                }
            }

            // Center: Permission error or mic button
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (!hasMicPermission) {
                        Text(
                            text = "Microphone permission required",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error
                        )
                        Text(
                            text = "Open app to grant permission",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    CircularMicButton(
                        state = when (state) {
                            KeyboardState.Idle -> MicButtonState.Idle
                            KeyboardState.Recording -> MicButtonState.Recording
                            KeyboardState.Processing -> MicButtonState.Processing
                        },
                        audioLevel = audioLevel,
                        frequencyBands = frequencyBands,
                        onClick = {
                            when (state) {
                                KeyboardState.Idle -> {
                                    if (hasMicPermission) {
                                        errorMessage = null
                                        val recorder = AudioRecorder(context)
                                        audioRecorder = recorder
                                        val file = recorder.start()
                                        if (file != null) {
                                            state = KeyboardState.Recording
                                        } else {
                                            errorMessage = "Failed to start recording"
                                        }
                                    }
                                }

                                KeyboardState.Recording -> {
                                    scope.launch {
                                        val result = audioRecorder?.stop()
                                        audioRecorder = null

                                        if (result != null && result.first != null && result.second >= 300) {
                                            state = KeyboardState.Processing
                                            val transcribeResult = transcribe(result.first!!)
                                            transcribeResult.fold(
                                                onSuccess = { text ->
                                                    if (text.isNotEmpty()) {
                                                        onTextInput(text)
                                                    }
                                                    state = KeyboardState.Idle
                                                },
                                                onFailure = { e ->
                                                    errorMessage = e.message ?: "Transcription failed"
                                                    state = KeyboardState.Idle
                                                }
                                            )
                                        } else {
                                            state = KeyboardState.Idle
                                        }
                                    }
                                }

                                KeyboardState.Processing -> {
                                    // Do nothing while processing
                                }
                            }
                        },
                        size = 100.dp
                    )
                }
            }

            // Bottom row: Backspace, space/gap, Send - like standard keyboard bottom row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Backspace button
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    shape = MaterialTheme.shapes.small,
                    color = MaterialTheme.colorScheme.surfaceContainerHigh
                ) {
                    RepeatingIconButton(
                        onClick = onBackspace,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.Backspace,
                            contentDescription = "Backspace",
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                // Spacer in middle
                Spacer(modifier = Modifier.weight(2f))

                // Send/Enter button
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    shape = MaterialTheme.shapes.small,
                    color = MaterialTheme.colorScheme.primary
                ) {
                    IconButton(
                        onClick = onEnter,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        Icon(
                            imageVector = when (enterKeyType) {
                                EnterKeyType.Send -> Icons.AutoMirrored.Filled.Send
                                EnterKeyType.NewLine -> Icons.AutoMirrored.Filled.KeyboardReturn
                            },
                            contentDescription = when (enterKeyType) {
                                EnterKeyType.Send -> "Send"
                                EnterKeyType.NewLine -> "New line"
                            },
                            tint = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                }
            }
        }
    }
}

/**
 * IconButton that repeats its onClick action while held down.
 * Initial delay before repeating, then faster repeat rate.
 */
@Composable
private fun RepeatingIconButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    initialDelay: Long = 500L,
    repeatDelay: Long = 50L,
    content: @Composable () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    var isPressed by remember { mutableStateOf(false) }

    // Handle repeat while pressed
    LaunchedEffect(isPressed) {
        if (isPressed) {
            onClick() // Initial click
            delay(initialDelay)
            while (isPressed) {
                onClick()
                delay(repeatDelay)
            }
        }
    }

    // Track press state
    LaunchedEffect(interactionSource) {
        interactionSource.interactions.collect { interaction ->
            when (interaction) {
                is PressInteraction.Press -> isPressed = true
                is PressInteraction.Release, is PressInteraction.Cancel -> isPressed = false
            }
        }
    }

    IconButton(
        onClick = { }, // Handled by LaunchedEffect
        modifier = modifier,
        interactionSource = interactionSource
    ) {
        content()
    }
}

package com.whispermate.aidictation.ui.screens.onboarding

import android.Manifest
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Keyboard
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.toMutableStateList
import kotlinx.coroutines.delay
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.whispermate.aidictation.R
import com.whispermate.aidictation.data.preferences.AppPreferences
import com.whispermate.aidictation.ui.components.CircularMicButton
import com.whispermate.aidictation.ui.components.MicButtonState

@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
    onSaveContextRules: (List<Boolean>) -> Unit = {}
) {
    var currentStep by remember { mutableIntStateOf(0) }
    var hasMicPermission by remember { mutableStateOf(false) }
    val context = LocalContext.current
    var isKeyboardEnabled by remember { mutableStateOf(isKeyboardEnabled(context)) }
    var isKeyboardSelected by remember { mutableStateOf(isKeyboardSelected(context)) }
    var hasDictated by remember { mutableStateOf(false) }
    val lifecycleOwner = LocalLifecycleOwner.current

    // Context rules enabled state
    val contextRulesEnabled = remember {
        AppPreferences.defaultContextRules.map { false }.toMutableStateList()
    }

    // Check keyboard status when returning from settings
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                isKeyboardEnabled = isKeyboardEnabled(context)
                isKeyboardSelected = isKeyboardSelected(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    // Poll for keyboard selection changes when on keyboard step
    LaunchedEffect(currentStep) {
        if (currentStep == 3) {
            while (true) {
                delay(500)
                isKeyboardEnabled = isKeyboardEnabled(context)
                isKeyboardSelected = isKeyboardSelected(context)
            }
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasMicPermission = isGranted
        if (isGranted) {
            currentStep = 2
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Progress indicator (sticky at top)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp),
            horizontalArrangement = Arrangement.Center
        ) {
            repeat(4) { index ->
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(
                            if (index <= currentStep) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outlineVariant
                        )
                )
                if (index < 3) {
                    Spacer(modifier = Modifier.width(8.dp))
                }
            }
        }

        // Scrollable content area
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            AnimatedContent(
                targetState = currentStep,
                transitionSpec = { fadeIn() togetherWith fadeOut() },
                label = "onboarding_step"
            ) { step ->
                when (step) {
                    0 -> WelcomeStep()
                    1 -> MicrophonePermissionStep(hasMicPermission)
                    2 -> ContextRulesStep(
                        enabledStates = contextRulesEnabled,
                        onToggle = { index, enabled -> contextRulesEnabled[index] = enabled }
                    )
                    3 -> KeyboardSetupStep(
                        isKeyboardEnabled = isKeyboardEnabled,
                        isKeyboardSelected = isKeyboardSelected,
                        hasDictated = hasDictated,
                        onTextChanged = { text -> hasDictated = text.isNotBlank() },
                        onOpenSettings = { openKeyboardSettings(context) },
                        onSelectKeyboard = { showKeyboardPicker(context) }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Bottom button (sticky at bottom)
        Button(
            onClick = {
                when (currentStep) {
                    0 -> currentStep = 1
                    1 -> {
                        if (hasMicPermission) {
                            currentStep = 2
                        } else {
                            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        }
                    }
                    2 -> {
                        onSaveContextRules(contextRulesEnabled.toList())
                        currentStep = 3
                    }
                    3 -> {
                        when {
                            !isKeyboardEnabled -> openKeyboardSettings(context)
                            !isKeyboardSelected -> showKeyboardPicker(context)
                            hasDictated -> onComplete()
                            // If keyboard selected but not dictated, do nothing (button disabled)
                        }
                    }
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            enabled = currentStep != 3 || !isKeyboardEnabled || !isKeyboardSelected || hasDictated,
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary
            )
        ) {
            Text(
                text = when (currentStep) {
                    0 -> stringResource(R.string.onboarding_continue)
                    1 -> if (hasMicPermission) stringResource(R.string.onboarding_continue)
                    else stringResource(R.string.onboarding_mic_enable)
                    2 -> stringResource(R.string.onboarding_continue)
                    3 -> when {
                        !isKeyboardEnabled -> stringResource(R.string.onboarding_open_settings)
                        !isKeyboardSelected -> "Select Keyboard"
                        hasDictated -> stringResource(R.string.onboarding_get_started)
                        else -> "Try dictation first"
                    }
                    else -> ""
                },
                style = MaterialTheme.typography.titleMedium
            )
        }
    }
}

@Composable
private fun WelcomeStep() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // App icon placeholder
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Mic,
                contentDescription = null,
                modifier = Modifier.size(36.dp),
                tint = MaterialTheme.colorScheme.primary
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = stringResource(R.string.onboarding_welcome_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = stringResource(R.string.onboarding_welcome_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Features
        FeatureItem(
            icon = Icons.Default.Translate,
            text = stringResource(R.string.onboarding_feature_1)
        )
        Spacer(modifier = Modifier.height(12.dp))
        FeatureItem(
            icon = Icons.Default.Speed,
            text = stringResource(R.string.onboarding_feature_2)
        )
        Spacer(modifier = Modifier.height(12.dp))
        FeatureItem(
            icon = Icons.Default.Security,
            text = stringResource(R.string.onboarding_feature_3)
        )
    }
}

@Composable
private fun MicrophonePermissionStep(hasPermission: Boolean) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(
                    if (hasPermission) MaterialTheme.colorScheme.primaryContainer
                    else MaterialTheme.colorScheme.secondaryContainer
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = if (hasPermission) Icons.Default.Check else Icons.Default.Mic,
                contentDescription = null,
                modifier = Modifier.size(36.dp),
                tint = if (hasPermission) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.secondary
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = stringResource(R.string.onboarding_mic_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = stringResource(R.string.onboarding_mic_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        if (hasPermission) {
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Permission granted",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

@Composable
private fun ContextRulesStep(
    enabledStates: List<Boolean>,
    onToggle: (Int, Boolean) -> Unit
) {
    val defaultRules = AppPreferences.defaultContextRules

    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Tune,
                contentDescription = null,
                modifier = Modifier.size(36.dp),
                tint = MaterialTheme.colorScheme.primary
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Speech Cleanup",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = "Choose which cleanup rules to apply to your dictation",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(16.dp))

        defaultRules.forEachIndexed { index, rule ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onToggle(index, !enabledStates[index]) }
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = MaterialTheme.shapes.small
                    )
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Checkbox(
                    checked = enabledStates[index],
                    onCheckedChange = { onToggle(index, it) },
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = rule.name,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = rule.instructions,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
        }
    }
}

@Composable
private fun KeyboardSetupStep(
    isKeyboardEnabled: Boolean,
    isKeyboardSelected: Boolean,
    hasDictated: Boolean,
    onTextChanged: (String) -> Unit,
    onOpenSettings: () -> Unit,
    onSelectKeyboard: () -> Unit
) {
    var testText by remember { mutableStateOf("") }
    val focusRequester = remember { FocusRequester() }

    // Auto-focus when keyboard becomes selected
    LaunchedEffect(isKeyboardSelected) {
        if (isKeyboardSelected) {
            focusRequester.requestFocus()
        }
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(
                    if (hasDictated) MaterialTheme.colorScheme.primaryContainer
                    else MaterialTheme.colorScheme.secondaryContainer
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = if (hasDictated) Icons.Default.Check else Icons.Default.Keyboard,
                contentDescription = null,
                modifier = Modifier.size(36.dp),
                tint = if (hasDictated) MaterialTheme.colorScheme.primary
                else MaterialTheme.colorScheme.secondary
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = stringResource(R.string.onboarding_keyboard_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = stringResource(R.string.onboarding_keyboard_subtitle),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Step 1: Enable keyboard
        SetupStepItem(
            number = "1",
            text = stringResource(R.string.onboarding_keyboard_step1),
            isCompleted = isKeyboardEnabled,
            onClick = if (!isKeyboardEnabled) onOpenSettings else null
        )
        Spacer(modifier = Modifier.height(8.dp))

        // Step 2: Select keyboard
        SetupStepItem(
            number = "2",
            text = stringResource(R.string.onboarding_keyboard_step2),
            isCompleted = isKeyboardSelected,
            onClick = if (isKeyboardEnabled && !isKeyboardSelected) onSelectKeyboard else null
        )
        Spacer(modifier = Modifier.height(8.dp))

        // Step 3: Try dictation
        SetupStepItem(
            number = "3",
            text = stringResource(R.string.onboarding_keyboard_step3),
            isCompleted = hasDictated,
            onClick = if (isKeyboardSelected && !hasDictated) {{ focusRequester.requestFocus() }} else null,
            trailingContent = if (isKeyboardSelected) {
                {
                    CircularMicButton(
                        state = MicButtonState.Idle,
                        onClick = { },
                        size = 28.dp
                    )
                }
            } else null
        )

        if (isKeyboardSelected) {
            Spacer(modifier = Modifier.height(12.dp))

            androidx.compose.material3.OutlinedTextField(
                value = testText,
                onValueChange = {
                    testText = it
                    onTextChanged(it)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focusRequester),
                placeholder = { Text("Say something like \"Hello, this is a test\"", style = MaterialTheme.typography.bodySmall) },
                minLines = 2,
                textStyle = MaterialTheme.typography.bodySmall,
                shape = MaterialTheme.shapes.small
            )
        }
    }
}

@Composable
private fun FeatureItem(icon: ImageVector, text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth(0.85f)
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.primary
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

@Composable
private fun SetupStepItem(
    number: String,
    text: String,
    isCompleted: Boolean = false,
    onClick: (() -> Unit)? = null,
    trailingContent: @Composable (() -> Unit)? = null
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (isCompleted) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
                else MaterialTheme.colorScheme.surfaceVariant,
                shape = MaterialTheme.shapes.small
            )
            .then(
                if (onClick != null) Modifier.clickable(onClick = onClick)
                else Modifier
            )
            .padding(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(
                    if (isCompleted) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.outline
                ),
            contentAlignment = Alignment.Center
        ) {
            if (isCompleted) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onPrimary
                )
            } else {
                Text(
                    text = number,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.surface
                )
            }
        }
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = if (isCompleted) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f)
        )
        if (!isCompleted && trailingContent != null) {
            trailingContent()
        }
    }
}

private fun openKeyboardSettings(context: Context) {
    val imeId = "${context.packageName}/${context.packageName}.service.AIDictationIME"

    try {
        // Try Samsung/OneUI style deep link first
        val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        intent.putExtra(":settings:show_fragment_args", android.os.Bundle().apply {
            putString(":settings:fragment_args_key", imeId)
        })
        intent.putExtra("HIGHLIGHT_IME", imeId)
        intent.putExtra("android.intent.extra.PACKAGE_NAME", context.packageName)
        context.startActivity(intent)
    } catch (e: Exception) {
        // Fallback to basic settings
        val intent = Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }
}

private fun showKeyboardPicker(context: Context) {
    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
    imm.showInputMethodPicker()
}

private fun isKeyboardEnabled(context: Context): Boolean {
    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
    val enabledInputMethods = imm.enabledInputMethodList
    return enabledInputMethods.any { it.packageName == context.packageName }
}

private fun isKeyboardSelected(context: Context): Boolean {
    val currentIme = Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
    // Format is "com.whispermate.aidictation/.service.AIDictationIME"
    return currentIme?.startsWith(context.packageName) == true
}

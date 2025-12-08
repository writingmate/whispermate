package com.whispermate.aidictation.ui.screens.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.whispermate.aidictation.data.preferences.AppPreferences
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val appPreferences: AppPreferences
) : ViewModel() {

    val hasCompletedOnboarding: StateFlow<Boolean> = appPreferences.hasCompletedOnboarding
        .stateIn(viewModelScope, SharingStarted.Eagerly, false)

    fun completeOnboarding() {
        viewModelScope.launch {
            appPreferences.setOnboardingCompleted(true)
        }
    }

    fun saveContextRulesFromOnboarding(enabledStates: List<Boolean>) {
        viewModelScope.launch {
            val defaultRules = AppPreferences.defaultContextRules
            val updatedRules = defaultRules.mapIndexed { index, rule ->
                rule.copy(isEnabled = enabledStates.getOrElse(index) { false })
            }
            appPreferences.saveContextRules(updatedRules)
        }
    }
}

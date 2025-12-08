package com.whispermate.aidictation.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.whispermate.aidictation.ui.screens.main.MainScreen
import com.whispermate.aidictation.ui.screens.onboarding.OnboardingScreen
import com.whispermate.aidictation.ui.screens.onboarding.OnboardingViewModel
import com.whispermate.aidictation.ui.screens.transcription.TranscriptionSettingsScreen

sealed class Screen(val route: String) {
    data object Onboarding : Screen("onboarding")
    data object Main : Screen("main")
    data object TranscriptionSettings : Screen("transcription_settings")
}

@Composable
fun AIDictationNavHost(
    navController: NavHostController = rememberNavController()
) {
    val onboardingViewModel: OnboardingViewModel = hiltViewModel()
    val hasCompletedOnboarding by onboardingViewModel.hasCompletedOnboarding.collectAsState()

    val startDestination = if (hasCompletedOnboarding) Screen.Main.route else Screen.Onboarding.route

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(Screen.Onboarding.route) {
            OnboardingScreen(
                onComplete = {
                    onboardingViewModel.completeOnboarding()
                    navController.navigate(Screen.Main.route) {
                        popUpTo(Screen.Onboarding.route) { inclusive = true }
                    }
                },
                onSaveContextRules = { enabledStates ->
                    onboardingViewModel.saveContextRulesFromOnboarding(enabledStates)
                }
            )
        }

        composable(Screen.Main.route) {
            MainScreen(
                onNavigateToTranscriptionSettings = {
                    navController.navigate(Screen.TranscriptionSettings.route)
                }
            )
        }

        composable(Screen.TranscriptionSettings.route) {
            TranscriptionSettingsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}

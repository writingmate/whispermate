package com.whispermate.aidictation.ui

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat

class ColorDebugActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.WHITE)
        }

        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }

        // Title
        mainLayout.addView(TextView(this).apply {
            text = "System Colors (API ${Build.VERSION.SDK_INT})"
            textSize = 20f
            setTextColor(Color.BLACK)
            setPadding(0, 0, 0, dp(16))
        })

        // Color groups
        if (Build.VERSION.SDK_INT >= 31) {
            addColorSection(mainLayout, "Neutral 1", listOf(
                "system_neutral1_0", "system_neutral1_10", "system_neutral1_50",
                "system_neutral1_100", "system_neutral1_200", "system_neutral1_300",
                "system_neutral1_400", "system_neutral1_500", "system_neutral1_600",
                "system_neutral1_700", "system_neutral1_800", "system_neutral1_900",
                "system_neutral1_1000"
            ))

            addColorSection(mainLayout, "Neutral 2", listOf(
                "system_neutral2_0", "system_neutral2_10", "system_neutral2_50",
                "system_neutral2_100", "system_neutral2_200", "system_neutral2_300",
                "system_neutral2_400", "system_neutral2_500", "system_neutral2_600",
                "system_neutral2_700", "system_neutral2_800", "system_neutral2_900",
                "system_neutral2_1000"
            ))

            addColorSection(mainLayout, "Accent 1 (Primary)", listOf(
                "system_accent1_0", "system_accent1_10", "system_accent1_50",
                "system_accent1_100", "system_accent1_200", "system_accent1_300",
                "system_accent1_400", "system_accent1_500", "system_accent1_600",
                "system_accent1_700", "system_accent1_800", "system_accent1_900",
                "system_accent1_1000"
            ))

            addColorSection(mainLayout, "Accent 2 (Secondary)", listOf(
                "system_accent2_0", "system_accent2_10", "system_accent2_50",
                "system_accent2_100", "system_accent2_200", "system_accent2_300",
                "system_accent2_400", "system_accent2_500", "system_accent2_600",
                "system_accent2_700", "system_accent2_800", "system_accent2_900",
                "system_accent2_1000"
            ))

            addColorSection(mainLayout, "Accent 3 (Tertiary)", listOf(
                "system_accent3_0", "system_accent3_10", "system_accent3_50",
                "system_accent3_100", "system_accent3_200", "system_accent3_300",
                "system_accent3_400", "system_accent3_500", "system_accent3_600",
                "system_accent3_700", "system_accent3_800", "system_accent3_900",
                "system_accent3_1000"
            ))
        }

        addColorSection(mainLayout, "Standard Colors", listOf(
            "background_light", "background_dark",
            "white", "black"
        ))

        scrollView.addView(mainLayout)
        setContentView(scrollView)
    }

    private fun addColorSection(parent: LinearLayout, title: String, colorNames: List<String>) {
        parent.addView(TextView(this).apply {
            text = title
            textSize = 16f
            setTextColor(Color.DKGRAY)
            setPadding(0, dp(16), 0, dp(8))
        })

        val grid = GridLayout(this).apply {
            columnCount = 3
            setPadding(0, 0, 0, dp(8))
        }

        colorNames.forEach { name ->
            val colorValue = getSystemColor(name)

            val item = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(4), dp(4), dp(4), dp(4))
                layoutParams = GridLayout.LayoutParams().apply {
                    width = 0
                    height = GridLayout.LayoutParams.WRAP_CONTENT
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                }
            }

            // Color swatch
            item.addView(TextView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(48)
                )
                if (colorValue != null) {
                    setBackgroundColor(colorValue)
                } else {
                    setBackgroundColor(Color.LTGRAY)
                    text = "N/A"
                    gravity = Gravity.CENTER
                }
            })

            // Color name
            item.addView(TextView(this).apply {
                text = name.removePrefix("system_")
                textSize = 10f
                setTextColor(Color.DKGRAY)
                maxLines = 1
            })

            // Hex value
            item.addView(TextView(this).apply {
                text = if (colorValue != null) {
                    String.format("#%08X", colorValue)
                } else {
                    "---"
                }
                textSize = 9f
                setTextColor(Color.GRAY)
            })

            grid.addView(item)
        }

        parent.addView(grid)
    }

    private fun getSystemColor(name: String): Int? {
        return try {
            val id = android.R.color::class.java.getField(name).getInt(null)
            ContextCompat.getColor(this, id)
        } catch (e: Exception) {
            null
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}

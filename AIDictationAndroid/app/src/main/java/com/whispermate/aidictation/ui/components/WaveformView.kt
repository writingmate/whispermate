package com.whispermate.aidictation.ui.components

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import androidx.core.content.ContextCompat
import rkr.simplekeyboard.inputmethod.R
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.PI

/**
 * A smooth waveform visualization view for audio recording.
 * Uses proper easing and animation techniques.
 */
class WaveformView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = ContextCompat.getColor(context, R.color.key_text_color_lxx_system)
    }

    // Extra bar for smooth scrolling (one off-screen to the right)
    private val barCount = 32
    private val totalBars = barCount + 1
    private val barWidthRatio = 0.35f
    private val minBarHeight = 0.1f
    private val bars = FloatArray(totalBars) { minBarHeight }
    private val targetBars = FloatArray(totalBars) { minBarHeight }
    private val velocities = FloatArray(totalBars) { 0f }

    // Spring animation parameters
    private val springStiffness = 0.15f
    private val springDamping = 0.7f

    // Smooth horizontal scroll offset (0 to 1, representing fraction of one bar spacing)
    private var scrollOffset = 0f
    private val scrollSpeed = 0.06f // How fast bars scroll per frame
    private var lastScrollTime = 0L

    private var audioLevel = 0f
    private var isRecording = false
    private var animator: ValueAnimator? = null

    init {
        // Continuous animation loop for smooth updates
        animator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1000L // 1 second cycle
            repeatCount = ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener {
                updateBars()
                if (isRecording) {
                    updateScroll()
                }
                invalidate()
            }
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        animator?.start()
    }

    override fun onDetachedFromWindow() {
        animator?.cancel()
        super.onDetachedFromWindow()
    }

    private fun updateBars() {
        for (i in 0 until totalBars) {
            // Spring physics for smooth easing
            val displacement = targetBars[i] - bars[i]
            val springForce = displacement * springStiffness
            velocities[i] += springForce
            velocities[i] *= springDamping
            bars[i] += velocities[i]

            // Clamp values
            bars[i] = bars[i].coerceIn(minBarHeight, 1f)
        }
    }

    private fun updateScroll() {
        // Use system time for consistent scroll speed regardless of frame rate
        val currentTime = System.nanoTime()
        if (lastScrollTime == 0L) {
            lastScrollTime = currentTime
            return
        }

        val deltaTime = (currentTime - lastScrollTime) / 1_000_000_000f // Convert to seconds
        lastScrollTime = currentTime

        // Scroll at constant rate: scrollSpeed bars per second
        scrollOffset += scrollSpeed * deltaTime * 60f // 60 = base frame rate

        // When we've scrolled one full bar position, shift arrays
        if (scrollOffset >= 1f) {
            scrollOffset -= 1f

            // Shift all arrays left
            for (i in 0 until totalBars - 1) {
                bars[i] = bars[i + 1]
                targetBars[i] = targetBars[i + 1]
                velocities[i] = velocities[i + 1]
            }

            // Add new bar at the end with current audio level
            val variation = (Math.random() * 0.2f).toFloat()
            val effectiveLevel = if (audioLevel < 0.05f) {
                minBarHeight
            } else {
                // Direct mapping - noise already filtered in AudioRecorder
                val scaled = kotlin.math.sqrt(audioLevel)
                scaled * (1f + variation) + minBarHeight
            }
            // Set target for spring animation, but start bar at current level for smoother entry
            targetBars[totalBars - 1] = effectiveLevel.coerceIn(minBarHeight, 1f)
            bars[totalBars - 1] = targetBars[totalBars - 1]
            velocities[totalBars - 1] = 0f
        }
    }

    fun setAudioLevel(level: Float) {
        audioLevel = level.coerceIn(0f, 1f)
        isRecording = true
    }

    fun reset() {
        for (i in bars.indices) {
            bars[i] = minBarHeight
            targetBars[i] = minBarHeight
            velocities[i] = 0f
        }
        audioLevel = 0f
        scrollOffset = 0f
        lastScrollTime = 0L
        isRecording = true // Start scrolling immediately
        invalidate()
    }

    /**
     * Set a wave position for processing animation.
     * @param position 0.0 to 1.0 representing wave position across the bars
     */
    fun setWavePosition(position: Float) {
        isRecording = false
        val waveCenter = position * barCount
        val waveWidth = 5f

        for (i in 0 until totalBars) {
            val distance = abs(i - waveCenter)
            val normalizedDist = (distance / waveWidth).coerceIn(0f, 1f)
            // Smooth bell curve falloff
            val intensity = if (normalizedDist < 1f) {
                easeOutQuad(1f - normalizedDist)
            } else 0f
            targetBars[i] = minBarHeight + intensity * 0.75f
        }
    }

    // Easing functions
    private fun easeOutCubic(t: Float): Float = 1f - (1f - t) * (1f - t) * (1f - t)

    private fun easeOutQuad(t: Float): Float = 1f - (1f - t) * (1f - t)

    private fun easeInOutSine(t: Float): Float = (-(cos(PI * t) - 1) / 2).toFloat()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val w = width.toFloat()
        val h = height.toFloat()
        val barSpacing = w / barCount
        val barWidth = barSpacing * barWidthRatio
        val centerY = h / 2

        // Draw bars with smooth scroll offset
        for (i in 0 until totalBars) {
            val barHeight = bars[i] * h * 0.8f
            // Offset position by scrollOffset for smooth movement
            val baseX = (i - scrollOffset) * barSpacing
            val left = baseX + (barSpacing - barWidth) / 2
            val right = left + barWidth

            // Skip bars that are fully off-screen
            if (right < 0 || left > w) continue

            val top = centerY - barHeight / 2
            val bottom = centerY + barHeight / 2

            canvas.drawRoundRect(left, top, right, bottom, barWidth / 2, barWidth / 2, paint)
        }
    }
}

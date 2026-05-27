package com.birdnet.birdnet_live

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ImageView
import android.widget.SeekBar
import android.widget.Spinner
import android.widget.TextView

class DetectionStatsWidgetConfigActivity : Activity() {
    private var appWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    private lateinit var timeframeSpinner: Spinner
    private lateinit var transparencySeek: SeekBar
    private lateinit var fontSeek: SeekBar
    private lateinit var transparencyValue: TextView
    private lateinit var fontValue: TextView
    private lateinit var previewSizeSpinner: Spinner

    private lateinit var previewImage: ImageView
    private lateinit var previewTitle: TextView
    private lateinit var previewLine1: TextView
    private lateinit var previewLine2: TextView
    private lateinit var previewLine3: TextView
    private lateinit var previewTotals: TextView

    private val timeframeValues = listOf(
        DetectionStatsWidgetContract.timeframe24h,
        DetectionStatsWidgetContract.timeframe7d,
        DetectionStatsWidgetContract.timeframe30d,
    )

    private val previewSizeValues = listOf("small", "medium", "large")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detection_stats_widget_config)

        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        bindViews()
        bindSpinners()
        bindControls()

        val settings = DetectionStatsWidgetStore.loadSettings(this, appWidgetId)
        timeframeSpinner.setSelection(timeframeValues.indexOf(settings.timeframe).coerceAtLeast(0))
        transparencySeek.progress = settings.transparencyPercent
        fontSeek.progress = settings.fontSizeSp - 11
        updateLabels()
        renderPreview()
    }

    private fun bindViews() {
        timeframeSpinner = findViewById(R.id.stats_config_timeframe)
        transparencySeek = findViewById(R.id.stats_config_transparency)
        fontSeek = findViewById(R.id.stats_config_font_size)
        transparencyValue = findViewById(R.id.stats_config_transparency_value)
        fontValue = findViewById(R.id.stats_config_font_size_value)
        previewSizeSpinner = findViewById(R.id.stats_config_preview_size)

        previewImage = findViewById(R.id.stats_preview_image)
        previewTitle = findViewById(R.id.stats_preview_title)
        previewLine1 = findViewById(R.id.stats_preview_line_1)
        previewLine2 = findViewById(R.id.stats_preview_line_2)
        previewLine3 = findViewById(R.id.stats_preview_line_3)
        previewTotals = findViewById(R.id.stats_preview_totals)

        findViewById<Button>(R.id.stats_config_save).setOnClickListener { saveAndFinish() }
        findViewById<Button>(R.id.stats_config_cancel).setOnClickListener { finish() }
    }

    private fun bindSpinners() {
        val timeframeAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.stats_widget_timeframes,
            android.R.layout.simple_spinner_item,
        )
        timeframeAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        timeframeSpinner.adapter = timeframeAdapter

        val previewAdapter = ArrayAdapter.createFromResource(
            this,
            R.array.stats_widget_preview_sizes,
            android.R.layout.simple_spinner_item,
        )
        previewAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        previewSizeSpinner.adapter = previewAdapter
    }

    private fun bindControls() {
        transparencySeek.max = 90
        fontSeek.max = 13

        val listener = object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                updateLabels()
                renderPreview()
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
        }
        transparencySeek.setOnSeekBarChangeListener(listener)
        fontSeek.setOnSeekBarChangeListener(listener)

        timeframeSpinner.setSelection(0)
        previewSizeSpinner.setSelection(2)

        timeframeSpinner.onItemSelectedListener = SimpleItemSelectedListener { renderPreview() }
        previewSizeSpinner.onItemSelectedListener = SimpleItemSelectedListener { renderPreview() }
    }

    private fun updateLabels() {
        transparencyValue.text = getString(
            R.string.stats_widget_transparency_value,
            transparencySeek.progress,
        )
        val fontSize = 11 + fontSeek.progress
        fontValue.text = getString(R.string.stats_widget_font_size_value, fontSize)
    }

    private fun renderPreview() {
        val settings = currentSettings()
        val detections = DetectionStatsWidgetStore.readDetections(this)
        val cutoff = DetectionStatsWidgetStore.timeframeCutoffMillis(
            settings.timeframe,
            System.currentTimeMillis(),
        )
        val filtered = detections.filter { it.timestampMs >= cutoff }
            .sortedByDescending { it.timestampMs }

        val previewSize = previewSizeValues.getOrElse(previewSizeSpinner.selectedItemPosition) { "large" }

        val latest = filtered.firstOrNull()
        previewImage.setImageResource(R.mipmap.ic_launcher)
        if (latest?.imagePath != null) {
            val bitmap = BitmapFactory.decodeFile(latest.imagePath)
            if (bitmap != null) previewImage.setImageBitmap(bitmap)
        }

        val fontSize = settings.fontSizeSp.toFloat()
        previewTitle.textSize = fontSize + 1
        previewLine1.textSize = fontSize
        previewLine2.textSize = fontSize
        previewLine3.textSize = fontSize
        previewTotals.textSize = fontSize

        when (previewSize) {
            "small" -> {
                previewTitle.text = getString(R.string.stats_widget_preview_small)
                previewLine1.text = latest?.commonName ?: getString(R.string.stats_widget_empty)
                previewLine2.text = getString(R.string.stats_widget_preview_latest_only)
                previewLine3.visibility = View.GONE
                previewTotals.visibility = View.GONE
            }
            "medium" -> {
                previewTitle.text = getString(R.string.stats_widget_preview_medium)
                previewLine1.text = filtered.getOrNull(0)?.commonName ?: "-"
                previewLine2.text = filtered.getOrNull(1)?.commonName ?: "-"
                previewLine3.text = filtered.getOrNull(2)?.commonName ?: "-"
                previewLine3.visibility = View.VISIBLE
                previewTotals.visibility = View.GONE
            }
            else -> {
                previewTitle.text = getString(R.string.stats_widget_preview_large)
                previewLine1.text = filtered.getOrNull(0)?.commonName ?: "-"
                previewLine2.text = filtered.getOrNull(1)?.commonName ?: "-"
                previewLine3.text = filtered.getOrNull(2)?.commonName ?: "-"
                previewLine3.visibility = View.VISIBLE

                val totalDetections = filtered.size
                val totalSpecies = filtered.map { it.scientificName }.toSet().size
                previewTotals.visibility = View.VISIBLE
                previewTotals.text = getString(
                    R.string.stats_widget_preview_totals,
                    totalDetections,
                    totalSpecies,
                )
            }
        }

        val alpha = ((100 - settings.transparencyPercent).coerceIn(10, 100) / 100.0f)
        findViewById<View>(R.id.stats_preview_card).alpha = alpha
    }

    private fun saveAndFinish() {
        val settings = currentSettings()
        DetectionStatsWidgetStore.saveSettings(this, appWidgetId, settings)
        DetectionStatsWidgetProvider.updateWidget(this, appWidgetId)

        val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, result)
        finish()
    }

    private fun currentSettings(): DetectionStatsWidgetSettings {
        val timeframe = timeframeValues.getOrElse(timeframeSpinner.selectedItemPosition) {
            DetectionStatsWidgetContract.timeframe24h
        }
        return DetectionStatsWidgetSettings(
            timeframe = timeframe,
            transparencyPercent = transparencySeek.progress,
            fontSizeSp = 11 + fontSeek.progress,
        )
    }
}

private class SimpleItemSelectedListener(
    private val onSelected: () -> Unit,
) : android.widget.AdapterView.OnItemSelectedListener {
    override fun onItemSelected(
        parent: android.widget.AdapterView<*>?,
        view: View?,
        position: Int,
        id: Long,
    ) {
        onSelected()
    }

    override fun onNothingSelected(parent: android.widget.AdapterView<*>?) = Unit
}

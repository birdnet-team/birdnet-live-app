# FAQ

Frequently asked questions.

## General

**Q: Does BirdNET Live require an internet connection?**
A: No. All inference runs on-device using the ONNX model. The only network features are optional and off by default: map tiles and place-name lookup from OpenStreetMap, weather snapshots from Open-Meteo, and species image and description lookups from the taxonomy API. See [Settings → Privacy](settings.md#privacy).

**Q: How many species can it identify?**
A: The BirdNET+ V3.0 model identifies 9,789 species worldwide — birds, amphibians, mammals, and insects (the taxonomy-matched pruned intersection of the audio classifier and geo-model).

**Q: What platforms are supported?**
A: Android (8.0+), iOS (15.0+), and Windows (experimental).

## Accuracy

**Q: Why is my confidence threshold showing low scores?**
A: Lower the confidence threshold in Settings to see more detections. Background noise, wind, and distance affect accuracy.

**Q: What does the species filter do?**
A: The geo-model predicts which species are likely at your GPS location and time of year. Enable **Location filter** to hide unlikely species, or **Location weighting** to weight results by geographic probability.

**Q: How accurate is the identification?**
A: Accuracy depends on recording quality, distance, background noise, and the species. High-confidence detections (>70%) are generally reliable. Always verify rare species visually.

## Recording

**Q: Where are recordings saved?**
A: In the app's documents directory under `recordings/<session-id>/`, as WAV or FLAC depending on **Settings → Recording → Format**.

**Q: Can I analyze existing recordings?**
A: Yes. Open File Analysis from the home screen, pick an audio file, set location and parameters, and tap Analyze. Supported formats include WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA, and AMR.

## Point Count

**Q: What is Point Count Mode?**
A: A timed survey mode for formal avian point-count observations. You set a fixed duration (3–20 minutes) and a location, and the app then runs continuously and stops automatically when the timer reaches zero.

**Q: Can I pause a point count?**
A: No. Protocol compliance requires uninterrupted recording. You can, however, end a count early with the stop button.

**Q: Where do point count results go?**
A: They appear in the Session Library as "Point Count #1", "#2", etc. You can review, edit, and export them like any other session.

## Performance

**Q: Why is the app warm / using battery?**
A: ONNX model inference is compute-intensive, and the screen stays on during live sessions. This is normal for real-time neural network processing.

**Q: The spectrogram looks frozen.**
A: Ensure microphone permission is granted and audio capture is active. Check that no other app is using the microphone.

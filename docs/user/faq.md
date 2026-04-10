# FAQ

Frequently asked questions.

## General

**Q: Does BirdNET Live require an internet connection?**
A: No. All inference runs on-device using the ONNX model. The only network features are species image/description lookups from the taxonomy API, which are optional.

**Q: How many species can it identify?**
A: The BirdNET+ V3.0 model identifies 5,250 bird species worldwide (the pruned intersection of the audio classifier and geo-model).

**Q: What platforms are supported?**
A: Android (8.0+), iOS (15.0+), and Windows (experimental).

## Accuracy

**Q: Why is my confidence threshold showing low scores?**
A: Lower the confidence threshold in Settings to see more detections. Background noise, wind, and distance affect accuracy.

**Q: What does the species filter do?**
A: The geo-model predicts which species are likely at your GPS location and time of year. Enable "Geo Exclude" to hide unlikely species, or "Geo Merge" to weight results by geographic probability.

**Q: How accurate is the identification?**
A: Accuracy depends on recording quality, distance, background noise, and the species. High-confidence detections (>70%) are generally reliable. Always verify rare species visually.

## Recording

**Q: Where are recordings saved?**
A: In the app's documents directory under `recordings/<session-id>/`. Full recordings are saved as WAV files.

**Q: Can I analyze existing recordings?**
A: File Analysis mode (coming soon) will support offline analysis of WAV/MP3 files.

## Performance

**Q: Why is the app warm / using battery?**
A: ONNX model inference is compute-intensive. The screen also stays on during live sessions. This is normal for real-time neural network processing.

**Q: The spectrogram looks frozen.**
A: Ensure microphone permission is granted and audio capture is active. Check that no other app is using the microphone.

/// How much room the live scrolling spectrogram takes on a session screen.
///
/// Applies to every real-time spectrogram (Live Mode, Point Count, Survey,
/// ARU). Session Review and other playback spectrograms are not affected.
enum SpectrogramSize {
  /// The usual height.
  full('full', 1.0),

  /// Three quarters of the usual height.
  medium('medium', 0.75),

  /// Half of the usual height.
  small('small', 0.5),

  /// No spectrogram at all; the detection list takes its room.
  off('off', 0.0);

  const SpectrogramSize(this.prefValue, this.heightFraction);

  /// Value stored in shared preferences.
  final String prefValue;

  /// Share of the full-size height this size keeps.
  final double heightFraction;

  /// Whether the spectrogram is shown at all.
  bool get isVisible => this != off;

  /// Parses a stored value, falling back to [full] for anything unknown.
  static SpectrogramSize fromPrefValue(String? value) {
    for (final size in values) {
      if (size.prefValue == value) return size;
    }
    return full;
  }

  /// Flex weights for a column that gives the spectrogram [spectrogram]
  /// parts and the pane it shares the column with [other] parts at full size.
  ///
  /// The spectrogram's weight shrinks by [heightFraction] while the combined
  /// weight stays the same, so the other pane grows by exactly what the
  /// spectrogram gives up. Only meaningful while [isVisible]; callers leave
  /// the spectrogram out of the tree when the size is [off].
  SpectrogramFlex flexFor({required int spectrogram, required int other}) {
    // x4 keeps the 0.75 and 0.5 fractions exact integers.
    const scale = 4;
    final total = (spectrogram + other) * scale;
    final scaled = (spectrogram * scale * heightFraction).round();
    return (spectrogram: scaled, other: total - scaled);
  }

  /// Flex weights for a column the spectrogram has to itself (landscape):
  /// the spectrogram keeps [heightFraction] of the height and the remainder
  /// is left empty.
  SpectrogramFlex get ownColumnFlex => flexFor(spectrogram: 1, other: 0);
}

/// Integer flex weights returned by [SpectrogramSize.flexFor].
typedef SpectrogramFlex = ({int spectrogram, int other});

// =============================================================================
// File Analysis Providers — Riverpod wiring for offline file analysis
// =============================================================================
//
// Connects the [FileAnalysisController] and analysis state to the widget tree.
//
// ### Provider dependency graph
//
// ```
// fileAnalysisControllerProvider
//   └─ fileAnalysisStateProvider
//   └─ fileAnalysisProgressProvider
// ```
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_analysis_controller.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// The [FileAnalysisController] for the file analysis pipeline.
///
/// Long-lived: persists as long as the app is running.  The ONNX model is
/// loaded once and reused across multiple file analyses.
final fileAnalysisControllerProvider = Provider<FileAnalysisController>((ref) {
  final controller = FileAnalysisController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

// ---------------------------------------------------------------------------
// Reactive state
// ---------------------------------------------------------------------------

/// Reactive [FileAnalysisState] — tracks the pipeline lifecycle.
final fileAnalysisStateProvider =
    StateProvider<FileAnalysisState>((ref) => FileAnalysisState.idle);

/// Reactive analysis progress.
final fileAnalysisProgressProvider =
    StateProvider<AnalysisProgress>((ref) => AnalysisProgress.zero);

/// The steps channel, packaged as a plugin.
///
/// The Dart side lives in the app (`health/data/steps_source.dart`);
/// this package exists so the Android side is registered with every
/// Flutter engine the app starts — the activity's, and the day-reset
/// job's background one, which is where the 3 AM pull runs
/// ([[Checkpoint-8]]). A channel registered from the activity alone
/// does not exist in a background engine.
library;

/// The method channel both sides agree on.
const stepsChannelName = 'harvest/steps';

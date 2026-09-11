import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'steps_source.g.dart';

/// Where this phone's steps can come from.
enum StepsBackend {
  /// The system's own health store. Whatever the phone already trusts
  /// — Samsung Health, Fit, the Pixel's counter — writes to it, so the
  /// number here agrees with the phone's own health app.
  healthConnect,

  /// The raw since-boot step counter, for a phone with no Health
  /// Connect at all.
  sensor,

  /// Nothing to read. The card says so rather than showing a zero.
  none,
}

/// What the platform said when asked.
@immutable
class StepsStatus {
  const StepsStatus({
    required this.backend,
    required this.granted,
    this.installable = false,
  });

  static const unavailable = StepsStatus(
    backend: StepsBackend.none,
    granted: false,
  );

  final StepsBackend backend;

  /// Whether the source may be read now. For the sensor this is known
  /// up front; for Health Connect it is learnt by trying, so a false
  /// here becomes true after the first successful read.
  final bool granted;

  /// Health Connect is on this phone but needs installing or updating
  /// from the store before it can be read.
  final bool installable;

  bool get usable => backend != StepsBackend.none;

  StepsStatus copyWith({bool? granted}) => StepsStatus(
    backend: backend,
    granted: granted ?? this.granted,
    installable: installable,
  );
}

/// A half-open window of wall-clock time, `[start, end)`.
typedef StepsWindow = ({DateTime start, DateTime end});

/// What a read of Health Connect came back with.
sealed class StepsTotals {
  const StepsTotals();
}

/// One total per window asked for, in order.
class StepsCounted extends StepsTotals {
  const StepsCounted(this.totals);

  final List<int> totals;
}

/// The read permission is not held. Ask, rather than showing zeros.
class StepsDenied extends StepsTotals {
  const StepsDenied();
}

/// The platform edge for steps — a real one on the phone, a fake in
/// the tests, the same as every other sensor-shaped thing in the app.
abstract interface class StepsSource {
  Future<StepsStatus> status();

  /// Shows whatever prompt the source needs. True when it may now be
  /// read.
  Future<bool> requestPermission();

  /// Health Connect only: step totals per window.
  Future<StepsTotals> totals(List<StepsWindow> windows);

  /// Sensor only: the since-boot count, or null when the sensor has
  /// nothing to say yet.
  Future<int?> counter();

  /// Opens Health Connect's own settings, or the store page to install
  /// it.
  Future<void> openHealthConnect();
}

/// The method channel to `StepsChannel.kt`.
class ChannelStepsSource implements StepsSource {
  const ChannelStepsSource();

  static const _channel = MethodChannel('harvest/steps');

  @override
  Future<StepsStatus> status() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('status');
      if (raw == null) return StepsStatus.unavailable;
      return StepsStatus(
        backend: switch (raw['backend']) {
          'healthConnect' => StepsBackend.healthConnect,
          'sensor' => StepsBackend.sensor,
          _ => StepsBackend.none,
        },
        granted: raw['granted'] == true,
        installable: raw['installable'] == true,
      );
    } on MissingPluginException {
      return StepsStatus.unavailable;
    } on PlatformException {
      return StepsStatus.unavailable;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<StepsTotals> totals(List<StepsWindow> windows) async {
    final raw = await _channel.invokeMethod<Object?>('readTotals', [
      for (final window in windows)
        [
          window.start.millisecondsSinceEpoch,
          window.end.millisecondsSinceEpoch,
        ],
    ]);
    if (raw is List) {
      return StepsCounted([for (final total in raw) (total as num).toInt()]);
    }
    return const StepsDenied();
  }

  @override
  Future<int?> counter() => _channel.invokeMethod<int>('readCounter');

  @override
  Future<void> openHealthConnect() =>
      _channel.invokeMethod<void>('openHealthConnect');
}

@Riverpod(keepAlive: true)
StepsSource stepsSource(Ref ref) => const ChannelStepsSource();

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_gateway.g.dart';

/// How much of my location the phone lets the app see.
enum LocationAccess {
  /// Refused, or never asked.
  none,

  /// Only while the app is on screen: enough for geotags.
  whileInUse,

  /// Also in the background: needed for the trail ([[Places]] PL1).
  always,

  /// The phone's location is switched off altogether.
  serviceOff,
}

/// The platform edge for location, with a fake in the tests — the same
/// shape as the steps source.
///
/// Every read goes through Android's own `LocationManager`, never Play
/// Services' fused provider: the fused one answers a quiet geotag by
/// putting a "turn on Location Accuracy" dialog over whatever is on
/// screen, and it is a Google service where the rest of Places uses
/// none ([[ADR-010-Maps]]).
abstract interface class LocationGateway {
  Future<LocationAccess> access();

  /// Asks for "while using the app". The first of the two asks.
  Future<LocationAccess> requestWhileInUse();

  /// Asks for "all the time". Android sends this to the settings page
  /// from API 30, so the answer may only be known on the next resume.
  Future<LocationAccess> requestAlways();

  /// One fresh fix, or null when none arrives within [timeout].
  Future<Fix?> currentFix({Duration timeout = const Duration(seconds: 10)});

  /// The phone's own last known position, however it got it; null when
  /// it has none.
  Future<Fix?> lastKnown();

  Future<void> openSettings();
}

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<LocationAccess> access() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceOff;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.always => LocationAccess.always,
        LocationPermission.whileInUse => LocationAccess.whileInUse,
        _ => LocationAccess.none,
      };
    } on PlatformException {
      return LocationAccess.none;
    }
  }

  @override
  Future<LocationAccess> requestWhileInUse() async {
    try {
      final current = await Geolocator.checkPermission();
      if (current == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } on PlatformException {
      return LocationAccess.none;
    }
    return access();
  }

  @override
  Future<LocationAccess> requestAlways() async {
    try {
      if (await access() == LocationAccess.none) await requestWhileInUse();
      // Android 10 offers "all the time" in the dialog itself. From 11
      // it lives only in the settings page, so a second ask that comes
      // back "while in use" goes there, and the next resume reads the
      // answer ([[Places]] PL1).
      if (await Geolocator.requestPermission() ==
          LocationPermission.whileInUse) {
        await Geolocator.openAppSettings();
      }
    } on PlatformException {
      return LocationAccess.none;
    }
    return access();
  }

  @override
  Future<Fix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
          forceLocationManager: true,
        ),
      );
      return fixOf(position);
    } on TimeoutException {
      return null;
    } on PlatformException {
      return null;
    } on LocationServiceDisabledException {
      return null;
    } on PermissionDeniedException {
      return null;
    }
  }

  @override
  Future<Fix?> lastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: true,
      );
      return position == null ? null : fixOf(position);
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}

Fix fixOf(Position position) => Fix(
  latitude: position.latitude,
  longitude: position.longitude,
  at: position.timestamp.toLocal(),
  accuracyM: position.accuracy,
  speedMps: position.speed >= 0 ? position.speed : null,
  altitudeM: position.altitude,
);

@Riverpod(keepAlive: true)
LocationGateway locationGateway(Ref ref) => const GeolocatorGateway();

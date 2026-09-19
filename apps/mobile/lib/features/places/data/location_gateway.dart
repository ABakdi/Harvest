import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
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
abstract interface class LocationGateway {
  Future<LocationAccess> access();

  /// Asks for "while using the app". The first of the two asks.
  Future<LocationAccess> requestWhileInUse();

  /// Asks for "all the time". Android sends this to the settings page
  /// from API 30, so the answer may only be known on the next resume.
  Future<LocationAccess> requestAlways();

  /// One fresh fix, or null when none arrives within [timeout].
  Future<Fix?> currentFix({Duration timeout = const Duration(seconds: 10)});

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
      await ph.Permission.locationWhenInUse.request();
    } on PlatformException {
      return LocationAccess.none;
    }
    return access();
  }

  @override
  Future<LocationAccess> requestAlways() async {
    try {
      if (await access() == LocationAccess.none) await requestWhileInUse();
      await ph.Permission.locationAlways.request();
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
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
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
  Future<void> openSettings() async {
    await ph.openAppSettings();
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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/app/app.dart';
import 'package:harvest/core/platform/day_reset.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) unawaited(DayResetJob.register());
  runApp(const ProviderScope(child: HarvestApp()));
}

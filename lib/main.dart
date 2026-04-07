import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';

void main() {
  MarionetteBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: RemuxApp(),
    ),
  );
}

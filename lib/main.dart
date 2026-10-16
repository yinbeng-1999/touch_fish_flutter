import 'package:flutter/material.dart';

import 'app.dart';
import 'widgets/float_screen.dart';

void main() => runApp(const FishingApp());

// The overlay plugin launches this entry point in its own Flutter engine.
@pragma('vm:entry-point')
void overlayMain() => runFloatScreen();

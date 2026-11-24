// ignore_for_file: deprecated_member_use

/// The Material import shared by the package's widgets.
///
/// `package:flutter/material.dart` is deliberately kept over
/// `package:material_ui`: on Flutter 3.47, `material_ui` has its own
/// `Theme`, invisible to a framework `MaterialApp` (the views would render
/// with `ThemeData.fallback()` — dark text on a dark surface); on 3.50+
/// `flutter/material.dart` itself re-exports `material_ui`, so this single
/// import resolves the consumer app's theme on both eras. The deprecation
/// notice fires only on 3.50+ and is silenced here, in one place.
library;

export 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';

import '../../core/widgets/particle_dissolve.dart';

/// Hands the splash's final picture to the first screen after it, so that
/// screen can open with the splash dissolving into dots on top.
///
/// The first page that claims it keeps it (rebuilds of the same page get
/// it again); it's cleared once the dissolve has finished.
abstract final class SplashExit {
  static ParticleGrid? _grid;
  static LocalKey? _owner;

  static void hold(ParticleGrid grid) {
    _grid = grid;
    _owner = null;
  }

  /// The grid for the page with [key], or null if there's none / it
  /// belongs to another page.
  static ParticleGrid? claim(LocalKey key) {
    if (_grid == null) return null;
    _owner ??= key;
    return _owner == key ? _grid : null;
  }

  static void clear() {
    _grid = null;
  }
}

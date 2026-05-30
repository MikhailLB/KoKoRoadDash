import 'package:flutter/widgets.dart';

import '../data/repositories/progress_repository.dart';

/// Exposes app-wide singletons (currently the progress repository) to the
/// widget tree without pulling in a third-party DI/state package.
///
/// Pair with [ListenableBuilder] when a widget needs to rebuild on changes.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.progress,
    required super.child,
  });

  final ProgressRepository progress;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  static ProgressRepository progressOf(BuildContext context) =>
      of(context).progress;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.progress != progress;
}

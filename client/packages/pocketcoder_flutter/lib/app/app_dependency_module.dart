import 'package:get_it/get_it.dart';

/// Application-specific dependency composition.
///
/// The shared package owns the interfaces and shared implementations. Each
/// distributable app supplies this module with its own implementations before
/// the generated shared Injectable graph is initialized.
abstract interface class AppDependencyModule {
  void register(GetIt getIt);
}

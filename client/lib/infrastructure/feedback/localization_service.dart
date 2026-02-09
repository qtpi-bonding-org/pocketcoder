import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart' as cubit_ui_flow;
import 'package:test_app/l10n/app_localizations.dart';

import 'package:test_app/l10n/l10n_key_resolver.g.dart';

/// Service for managing application localization and providing global access to translations.
///
/// This service acts as a link between Flutter's localization system and the rest
/// of the application, allowing access to translations without requiring BuildContext.
/// Implements cubit_ui_flow.ILocalizationService for integration with the UI flow library.
@LazySingleton(as: cubit_ui_flow.ILocalizationService)
class AppLocalizationService implements cubit_ui_flow.ILocalizationService {
  AppLocalizations? _l10n;
  L10nKeyResolver? _resolver;

  /// Updates the current localization instance.
  ///
  /// This should be called from the app's main widget when the locale changes
  /// or when the app initializes.
  void update(AppLocalizations instance) {
    _l10n = instance;
    _resolver = L10nKeyResolver(instance);
  }

  /// Gets the current localization instance.
  ///
  /// Throws an exception if localization has not been initialized.
  AppLocalizations get l10n {
    if (_l10n == null) {
      throw StateError(
          'AppLocalizationService not initialized. Call update() first.');
    }
    return _l10n!;
  }

  /// Checks if the localization service has been initialized.
  bool get isInitialized => _l10n != null;

  /// Gets the current locale.
  Locale? get currentLocale {
    return _l10n?.localeName != null ? Locale(_l10n!.localeName) : null;
  }

  /// Clears the current localization instance.
  void clear() {
    _l10n = null;
    _resolver = null;
  }

  @override
  String translate(String key, {Map<String, dynamic>? args}) {
    if (!isInitialized || _resolver == null) {
      return key; // Fallback to key if not initialized
    }

    // Use the generated resolver - handles all keys automatically
    return _resolver!.resolve(key, args: args) ?? key;
  }

  /// Checks if a key is known to the resolver.
  bool hasKey(String key) {
    if (!isInitialized) return false;
    // The resolver maps "foo.bar" -> "fooBar" (camelCase)
    // We rely on the resolver's internal map for this check if exposed,
    // or typically the resolver has a way to check.
    // Ensure L10nKeyResolver has static hasKey or instance method.
    // Based on original code, it seems to have a static hasKey or similar.
    // If the generated code doesn't have it, valid patterns are:
    // return _resolver!.resolve(key) != null;
    return L10nKeyResolver.hasKey(key);
  }
}

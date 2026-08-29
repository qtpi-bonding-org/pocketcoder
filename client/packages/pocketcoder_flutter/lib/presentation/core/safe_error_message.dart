import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:get_it/get_it.dart';

/// Converts an exception to localized, user-safe text without exposing its
/// implementation details when no dedicated mapping exists.
String safeErrorMessage(Object? error) {
  if (error == null) return '';

  var key = MessageKey.genericError;
  try {
    key = GetIt.instance<IExceptionKeyMapper>().map(error) ?? key;
  } catch (_) {}

  try {
    return GetIt.instance<ILocalizationService>()
        .translate(key.key, args: key.args);
  } catch (_) {
    return key.key;
  }
}

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:get_it/get_it.dart';

MessageKey safeErrorKey(Object error) {
  try {
    return GetIt.instance<IExceptionKeyMapper>().map(error) ??
        MessageKey.genericError;
  } catch (_) {
    return MessageKey.genericError;
  }
}

/// Converts an exception to localized, user-safe text without exposing its
/// implementation details when no dedicated mapping exists.
String safeErrorMessage(Object? error) {
  if (error == null) return '';

  final key = safeErrorKey(error);
  try {
    return GetIt.instance<ILocalizationService>()
        .translate(key.key, args: key.args);
  } catch (_) {
    return key.key;
  }
}

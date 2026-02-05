import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

/// Global exception mapper for the application.
///
/// Maps all application exceptions to user-friendly message keys
/// that can be localized and displayed to users.
@LazySingleton(as: IExceptionKeyMapper)
class AppExceptionKeyMapper implements IExceptionKeyMapper {
  @override
  MessageKey? map(Object exception) {
    // Return null to let fallback handling take over,
    // or return a MessageKey.error('your.key')
    // to show a specific error message.

    // Example mapping:
    // return switch (exception) {
    //   NetworkException() => MessageKey.networkError,
    //   TimeoutException() => const MessageKey.error('error.timeout'),
    //   UnauthorizedException() => const MessageKey.error('error.auth.unauthorized'),
    //   _ => null,
    // };

    return null;
  }
}

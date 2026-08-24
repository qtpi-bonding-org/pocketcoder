// Regression test for a confirmed live bug: ChatAdapter's own VimToast call
// rendered `'${value.error}'` directly, bypassing the exception mapper
// entirely -- an unmapped or default-toString() error showed literally
// "Instance of 'ProviderReauthenticationRequired'" in a toast, layered on
// top of ChatView's already-correct dedicated reauthentication banner for
// that exact case.
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/application/agent/provider_reauthentication_required.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/feedback/exception_mapper.dart';
import 'package:pocketcoder_flutter/presentation/chat/adapters/chat_adapter.dart';

class _FakeLocalizationService implements ILocalizationService {
  @override
  String translate(String key, {Map<String, dynamic>? args}) => key;
}

void main() {
  setUp(() {
    GetIt.instance.reset();
    GetIt.instance
        .registerSingleton<IExceptionKeyMapper>(AppExceptionKeyMapper());
    GetIt.instance
        .registerSingleton<ILocalizationService>(_FakeLocalizationService());
  });

  test('returns null for a null error (no toast to show)', () {
    expect(chatErrorToastMessage(null), isNull);
  });

  test(
      'returns null for ProviderReauthenticationRequired -- the dedicated '
      "inline banner already communicates it, so a toast (previously "
      "raw 'Instance of ProviderReauthenticationRequired' text) would "
      'only be redundant or leak internal detail', () {
    expect(chatErrorToastMessage(const ProviderReauthenticationRequired()),
        isNull);
  });

  test(
      'never returns raw exception text for any other error, even one '
      'with no dedicated mapper entry', () {
    final message = chatErrorToastMessage(ObservabilityException('boom'));
    expect(message, isNotNull);
    expect(message, isNot(contains('Instance of')));
    expect(message, isNot(contains('boom')));
    expect(message, isNot(contains('ObservabilityException')));
  });
}

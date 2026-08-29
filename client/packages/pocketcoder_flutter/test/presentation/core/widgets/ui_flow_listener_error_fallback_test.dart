// Regression test: UiFlowListener's built-in error handling (_handleErrorState
// / _handleMappedState) used to fall back to `state.error.toString()` when
// no AppExceptionKeyMapper entry existed for the error -- rendering Dart's
// default Object.toString() ("Instance of '...'") directly to the user for
// any genuinely-unmapped exception type. It must now fall back to a safe,
// generic, localized message instead.
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

class _TestState implements IUiFlowState {
  const _TestState({required this.status, this.error});

  @override
  final UiFlowStatus status;
  @override
  final Object? error;

  @override
  IUiFlowState withLoading() =>
      const _TestState(status: UiFlowStatus.loading);
  @override
  IUiFlowState withError(Object error) =>
      _TestState(status: UiFlowStatus.failure, error: error);

  @override
  bool get hasError => error != null;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
}

class _TestCubit extends Cubit<_TestState> {
  _TestCubit() : super(const _TestState(status: UiFlowStatus.idle));
  void fail(Object error) =>
      emit(_TestState(status: UiFlowStatus.failure, error: error));
}

/// Simulates an exception type with no AppExceptionKeyMapper entry --
/// Dart's default Object.toString() would render this as
/// "Instance of '_UnmappedError'".
class _UnmappedError {}

class _CapturingFeedbackService implements IFeedbackService {
  FeedbackMessage? last;
  @override
  void show(FeedbackMessage message) => last = message;
}

class _AlwaysNullExceptionMapper implements IExceptionKeyMapper {
  @override
  MessageKey? map(Object exception) => null;
}

class _EchoLocalizationService implements ILocalizationService {
  @override
  String translate(String key, {Map<String, dynamic>? args}) =>
      key == MessageKey.genericError.key ? 'Something went wrong' : key;
}

void main() {
  late _CapturingFeedbackService feedback;
  late _TestCubit cubit;

  setUp(() {
    GetIt.instance.reset();
    feedback = _CapturingFeedbackService();
    GetIt.instance.registerSingleton<IFeedbackService>(feedback);
    GetIt.instance
        .registerSingleton<IExceptionKeyMapper>(_AlwaysNullExceptionMapper());
    GetIt.instance
        .registerSingleton<ILocalizationService>(_EchoLocalizationService());
    cubit = _TestCubit();
  });

  tearDown(() async {
    await cubit.close();
  });

  testWidgets(
      'an unmapped exception reaching the built-in error handler never '
      'renders as raw Object.toString() text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<_TestCubit>.value(
        value: cubit,
        child: UiFlowListener<_TestCubit, _TestState>(
          autoDismissLoading: false,
          child: const SizedBox.shrink(),
        ),
      ),
    ));

    cubit.fail(_UnmappedError());
    await tester.pump();

    expect(feedback.last, isNotNull);
    expect(feedback.last!.message, isNot(contains('Instance of')));
    expect(feedback.last!.message, isNot(contains('_UnmappedError')));
    expect(feedback.last!.message, 'Something went wrong');
  });
}

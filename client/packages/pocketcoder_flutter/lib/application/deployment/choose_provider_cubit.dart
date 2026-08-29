import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

class ChooseProviderState with UiFlowStateMixin {
  const ChooseProviderState({
    this.options = const [],
    this.status = UiFlowStatus.idle,
    this.error,
  });

  final List<ProviderOption> options;
  @override
  final UiFlowStatus status;
  @override
  final Object? error;

  ChooseProviderState copyWith({
    UiFlowStatus? status,
    Object? error,
  }) =>
      ChooseProviderState(
        options: options,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

class ChooseProviderCubit extends AppCubit<ChooseProviderState> {
  ChooseProviderCubit(IProviderOptionService service)
      : super(ChooseProviderState(options: service.getAvailableProviders()));

  void fail(Object error) {
    emit(state.copyWith(status: UiFlowStatus.failure, error: error));
  }
}

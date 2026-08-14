import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

class DeployPickerState with UiFlowStateMixin {
  const DeployPickerState({
    this.options = const [],
    this.status = UiFlowStatus.idle,
    this.error,
  });

  final List<DeployOption> options;
  @override
  final UiFlowStatus status;
  @override
  final Object? error;
}

class DeployPickerCubit extends AppCubit<DeployPickerState> {
  DeployPickerCubit(IDeployOptionService service)
      : super(DeployPickerState(options: service.getAvailableProviders()));
}

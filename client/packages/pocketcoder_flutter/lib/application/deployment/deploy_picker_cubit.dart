import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';

class DeployPickerState {
  const DeployPickerState({this.options = const []});

  final List<DeployOption> options;
}

class DeployPickerCubit extends Cubit<DeployPickerState> {
  DeployPickerCubit(IDeployOptionService service)
      : super(DeployPickerState(options: service.getAvailableProviders()));
}

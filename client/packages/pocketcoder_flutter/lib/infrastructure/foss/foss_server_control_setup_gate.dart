import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_cubit.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_setup_gate.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';
import 'package:pocketcoder_flutter/presentation/foss/foss_server_setup_view.dart';

class FossServerControlSetupGate implements IServerControlSetupGate {
  const FossServerControlSetupGate(this._store);

  final FossRootSshCredentialsStore _store;

  @override
  Future<Widget?> resolveSetupScreen({
    required VoidCallback onSetupComplete,
  }) async {
    final existing = await _store.load();
    if (existing != null) return null;
    return BlocProvider(
      create: (_) => getIt<FossServerSetupCubit>(),
      child: FossServerSetupView(onSetupComplete: onSetupComplete),
    );
  }
}

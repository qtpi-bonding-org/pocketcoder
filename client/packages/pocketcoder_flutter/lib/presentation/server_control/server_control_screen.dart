import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/presentation/server_control/server_control_view.dart';

class ServerControlScreen extends StatelessWidget {
  const ServerControlScreen({
    super.key,
    required this.instanceId,
  });

  final String instanceId;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ServerControlCubit(
          getIt<IServerControlService>(),
          getIt.isRegistered<IServerConnectionDetailsProvider>()
              ? getIt<IServerConnectionDetailsProvider>()
              : null,
        )
          ..inspectRelease(),
        child: ServerControlView(instanceId: instanceId),
      );
}

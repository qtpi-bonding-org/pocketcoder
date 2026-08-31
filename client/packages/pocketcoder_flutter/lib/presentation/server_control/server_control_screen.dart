import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/domain/security/i_local_auth_gate.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_provider_console_link.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_setup_gate.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/server_control/server_control_view.dart';

class ServerControlScreen extends StatefulWidget {
  const ServerControlScreen({
    super.key,
    required this.instanceId,
  });

  final String instanceId;

  @override
  State<ServerControlScreen> createState() => _ServerControlScreenState();
}

class _ServerControlScreenState extends State<ServerControlScreen> {
  Future<Widget?>? _setupScreen;

  @override
  void initState() {
    super.initState();
    _resolveSetupScreen();
  }

  void _resolveSetupScreen() {
    setState(() {
      _setupScreen = GetIt.instance.isRegistered<IServerControlSetupGate>()
          ? GetIt.instance<IServerControlSetupGate>()
              .resolveSetupScreen(onSetupComplete: _resolveSetupScreen)
          : Future.value(null);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget?>(
        future: _setupScreen,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ERROR: ${snapshot.error}'),
                  TextButton(
                    onPressed: _resolveSetupScreen,
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            );
          }
          if (snapshot.data case final setupWidget?) {
            return setupWidget;
          }
          return BlocProvider(
            create: (_) => ServerControlCubit(
              getIt<IServerControlService>(),
              getIt<ILocalAuthGate>(),
              getIt.isRegistered<IServerConnectionDetailsProvider>()
                  ? getIt<IServerConnectionDetailsProvider>()
                  : null,
            )
              ..inspectRelease()
              ..loadPublicKey(widget.instanceId),
            child: ServerControlView(
              instanceId: widget.instanceId,
              inAppBrowserLauncher: getIt<InAppBrowserLauncher>(),
              providerConsoleLink: getIt.isRegistered<IProviderConsoleLink>()
                  ? getIt<IProviderConsoleLink>()
                  : null,
            ),
          );
        },
      );
}

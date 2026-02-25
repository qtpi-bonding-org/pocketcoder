import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../app_router.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  // State Machine
  bool _logsDimmed = false;
  bool _pocoVisible = false;
  // Data
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startBootSequence() async {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _wakeUpPoco();
    });

    String fileContent = '';
    try {
      // Try package path first (for monorepo/web consistency)
      fileContent = await rootBundle
          .loadString('packages/pocketcoder_flutter/assets/boot_log.txt');
    } catch (e) {
      try {
        // Fallback to direct path
        fileContent = await rootBundle.loadString('assets/boot_log.txt');
      } catch (e2) {
        fileContent =
            'SYSTEM_ERROR: UNABLE_TO_LOAD_BOOT_LOGS\n[!] CHECK_ASSET_MANIFEST\n';
      }
    }

    final bootLogs = fileContent.split('\n');

    if (mounted) {
      setState(() {
        _logs.addAll(bootLogs);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final duration = Duration(milliseconds: bootLogs.length * 20);
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: duration,
          curve: Curves.linear,
        );
      }
    });

    Future.delayed(Duration(milliseconds: bootLogs.length * 20), () {
      if (mounted) _startBackgroundLogs();
    });
  }

  void _wakeUpPoco() async {
    if (mounted) {
      context.read<PocoCubit>().reset(
            "Hi! I'm Poco, your Private Operations Coding Officer representing the PocketCoder Initiative.",
          );
      context.read<PocoCubit>().setExpression([
        (PocoExpression.sleepy, 1000),
        (PocoExpression.awake, 200), // Blink
        (PocoExpression.sleepy, 200),
        (PocoExpression.awake, 2000),
      ]);
      setState(() {
        _logsDimmed = true;
        _pocoVisible = true;
      });
    }

    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      _checkConnection();
    }
  }

  void _startBackgroundLogs() async {
    final noise = [
      '[sys] heartbeat: ok',
      '[net] keepalive sent',
      '[mem] gc_minor completed',
      '[proc] context_switch: 1241',
      '[agent] reasoning_engine: idle',
    ];

    int i = 0;
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _logs.add(noise[i % noise.length]);
        });
        i++;
      }
    }
  }

  Future<void> _checkConnection() async {
    const skipAuthDefine =
        String.fromEnvironment('SKIP_AUTH', defaultValue: 'false');
    final skipAuthEnv = dotenv.get('SKIP_AUTH', fallback: 'false');

    if (skipAuthDefine == 'true' || skipAuthEnv == 'true') {
      debugPrint('[PocketCoder] SKIP_AUTH is enabled. Bypassing login...');
      if (mounted) context.goNamed(RouteNames.home);
      return;
    }

    if (mounted) {
      context.read<PocoCubit>().updateMessage("Checking secure connection...");
    }

    bool connected = false;
    try {
      connected = await getIt<IStatusRepository>().checkPocketBaseHealth();
    } catch (_) {
      connected = false;
    }

    if (mounted) {
      if (connected) {
        context.read<PocoCubit>().updateMessage(
              "Systems nominal. I'm ready.",
              sequence: PocoExpressions.happy,
            );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.goNamed('onboarding');
      } else {
        context.read<PocoCubit>().updateMessage(
          "Connection failed. I'll take you back to the setup screen so we can check the server settings.",
          sequence: [
            (PocoExpression.nervous, 500),
            (PocoExpression.lookRight, 1000),
            (PocoExpression.awake, 1000),
          ],
        );
        // Wait a bit longer to let the user read before moving
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) context.goNamed('onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(seconds: 1),
              opacity: _logsDimmed ? 0.2 : 1.0,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(AppSizes.space * 2),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                    ),
                  );
                },
              ),
            ),
            if (_pocoVisible)
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PocoWidget(pocoSize: AppSizes.fontBig),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

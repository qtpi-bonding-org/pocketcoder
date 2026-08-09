import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'boot_view.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

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
        if (!mounted) return;
        fileContent = '${context.l10n.bootLoadError}\n';
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
            context.l10n.bootPocoIntro,
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
    OnboardingLogger.event('boot connection check started');
    if (mounted) {
      context
          .read<PocoCubit>()
          .updateMessage(context.l10n.bootCheckingConnection);
    }

    bool pocketbaseAlive = false;

    try {
      pocketbaseAlive = await getIt<IStatusRepository>()
          .checkPocketBaseHealth()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      pocketbaseAlive = false;
    }

    if (mounted) {
      if (pocketbaseAlive) {
        OnboardingLogger.event('PocketBase reachable; opening server session');
        // Now check if we're already logged in
        final authRepo = getIt<IAuthRepository>();
        bool alreadyLoggedIn = authRepo.isAuthenticated;

        if (alreadyLoggedIn) {
          try {
            // Try to refresh token silently
            alreadyLoggedIn = await authRepo.refreshToken();
          } catch (_) {
            alreadyLoggedIn = false;
          }
        }

        if (!mounted) return;

        context.read<PocoCubit>().updateMessage(
              alreadyLoggedIn
                  ? context.l10n.bootWelcomeBack
                  : context.l10n.bootSystemsNominal,
              sequence: PocoExpressions.happy,
            );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          if (alreadyLoggedIn) {
            context.goNamed(RouteNames.home);
          } else {
            // A reachable server needs credentials, not a server choice.
            context.goNamed(RouteNames.onboardingLogin);
          }
        }
      } else {
        context.read<PocoCubit>().updateMessage(
          context.l10n.bootConnectionFailed,
          sequence: [
            (PocoExpression.nervous, 500),
            (PocoExpression.lookRight, 1000),
            (PocoExpression.awake, 1000),
          ],
        );
        // Wait a bit longer to let the user read before moving
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) context.goNamed(RouteNames.onboarding);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PocoState>(
      initialData: context.read<PocoCubit>().state,
      stream: context.read<PocoCubit>().stream,
      builder: (context, snapshot) => BootView(
        logs: _logs,
        logsDimmed: _logsDimmed,
        pocoVisible: _pocoVisible,
        pocoState: snapshot.data ?? context.read<PocoCubit>().state,
        scrollController: _scrollController,
      ),
    );
  }
}

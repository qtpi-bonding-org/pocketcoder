import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'boot_view.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _logsDimmed = false;
  bool _pocoVisible = false;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _backgroundLogTimer;

  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  @override
  void dispose() {
    _backgroundLogTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startBootSequence() async {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _wakeUpPoco();
    });

    String fileContent = '';
    try {
      fileContent = await rootBundle
          .loadString('packages/pocketcoder_flutter/assets/boot_log.txt');
    } catch (e) {
      try {
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

  void _startBackgroundLogs() {
    final noise = [
      '[sys] heartbeat: ok',
      '[net] keepalive sent',
      '[mem] gc_minor completed',
      '[proc] context_switch: 1241',
      '[agent] reasoning_engine: idle',
    ];

    var i = 0;
    _backgroundLogTimer?.cancel();
    _backgroundLogTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {
          _logs.add(noise[i % noise.length]);
        });
        i++;
      }
    });
  }

  /// True only if nothing has navigated away from /boot yet.
  bool _stillOnBoot() => GoRouter.of(context).state.name == RouteNames.boot;

  Future<void> _checkConnection() async {
    OnboardingLogger.event('boot connection check started');

    if (mounted) {
      context
          .read<PocoCubit>()
          .updateMessage(context.l10n.bootCheckingConnection);
    }

    if (!mounted) return;

    final savedBaseUrl = await getIt<IAuthRepository>().getSavedBaseUrl();
    if (!mounted) return;

    if (savedBaseUrl == null) {
      OnboardingLogger.event('no saved instance data; routing to onboarding');
      context.read<PocoCubit>().updateMessage(
            context.l10n.bootSystemsNominal,
            sequence: PocoExpressions.happy,
          );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _stillOnBoot()) context.goNamed(RouteNames.onboarding);
      return;
    }

    final sessionState = await getIt<AuthSessionCoordinator>().restore();
    if (!mounted) return;

    var staleSessionResolved = false;
    if (sessionState == AuthSessionState.temporarilyUnavailable &&
        getIt.isRegistered<IInstanceExistenceResolver>()) {
      staleSessionResolved = await getIt<IInstanceExistenceResolver>()
          .resolveStaleSessionIfInstanceGone();
      if (!mounted) return;
    }

    if (staleSessionResolved) {
      context.read<PocoCubit>().updateMessage(
            context.l10n.bootConnectionFailed,
            sequence: [
              (PocoExpression.nervous, 500),
              (PocoExpression.lookRight, 1000),
              (PocoExpression.awake, 1000),
            ],
          );
      await Future.delayed(const Duration(seconds: 3));
      if (mounted && _stillOnBoot()) context.goNamed(RouteNames.onboarding);
      return;
    }

    final hasValidSession = sessionState != AuthSessionState.signedOut;
    if (hasValidSession) {
      OnboardingLogger.event(
        sessionState == AuthSessionState.signedIn
            ? 'PocketBase session restored'
            : 'PocketBase unavailable; preserving local session',
      );
      context.read<PocoCubit>().updateMessage(
            sessionState == AuthSessionState.signedIn
                ? context.l10n.bootWelcomeBack
                : context.l10n.bootConnectionFailed,
            sequence: PocoExpressions.happy,
          );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _stillOnBoot()) context.goNamed(RouteNames.home);
      return;
    }

    OnboardingLogger.event('instance data present, no session; routing to login');
    context.read<PocoCubit>().updateMessage(
          context.l10n.bootSystemsNominal,
          sequence: PocoExpressions.happy,
        );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _stillOnBoot()) context.goNamed(RouteNames.onboardingLogin);
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

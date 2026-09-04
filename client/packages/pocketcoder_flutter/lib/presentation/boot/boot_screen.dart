import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'boot_view.dart';

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

    await Future.delayed(const Duration(milliseconds: 6500));
    if (mounted) {
      _checkConnection();
    }
  }

  void _startBackgroundLogs() {
    final noise = [
      context.l10n.bootNoiseHeartbeat,
      context.l10n.bootNoiseKeepalive,
      context.l10n.bootNoiseGcMinor,
      context.l10n.bootNoiseContextSwitch,
      context.l10n.bootNoiseReasoningEngine,
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

  Future<void> _checkConnection() async {
    if (mounted) {
      context
          .read<PocoCubit>()
          .updateMessage(context.l10n.bootCheckingConnection);
    }
    context.read<PocoCubit>().updateMessage(
          context.l10n.bootSystemsNominal,
          sequence: PocoExpressions.happy,
        );
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

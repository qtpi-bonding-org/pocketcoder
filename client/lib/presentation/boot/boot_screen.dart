import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/design_system/primitives/app_fonts.dart';
import 'package:test_app/design_system/primitives/app_palette.dart';
import 'package:test_app/design_system/primitives/app_sizes.dart';
import 'package:test_app/design_system/primitives/spacers.dart';
import 'package:test_app/presentation/core/widgets/scanline_widget.dart';
import 'package:test_app/presentation/core/widgets/terminal_input.dart';
import '../core/widgets/ascii_art.dart';
import '../core/widgets/poco_widget.dart';
import '../../application/system/poco_cubit.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  // State Machine
  bool _logsDimmed = false;
  bool _pocoVisible = false;
  bool _showConfig = false;

  // Data
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _urlController =
      TextEditingController(text: 'http://127.0.0.1:8090');

  @override
  void initState() {
    super.initState();
    _startBootSequence();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _startBootSequence() async {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _wakeUpPoco();
    });

    String fileContent = await rootBundle.loadString('assets/boot_log.txt');
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
        (AppAscii.pocoSleepy, 1000),
        (AppAscii.pocoAwake, 200), // Blink
        (AppAscii.pocoSleepy, 200),
        (AppAscii.pocoAwake, 2000),
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
    // Simulate failure by default, but allow checking the variable to avoid dead code warning
    final connected = _urlController.text.contains('success');

    if (mounted) {
      context.read<PocoCubit>().updateMessage("Checking secure connection...");
    }

    await Future.delayed(const Duration(seconds: 2));

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
          "I lost the signal... Where is home?",
          sequence: [
            (AppAscii.pocoNervous, 500),
            (AppAscii.pocoPanic, 2000),
            (AppAscii.pocoNervous, 1000),
          ],
        );
        setState(() {
          _showConfig = true;
        });
      }
    }
  }

  Future<void> _handleConfigRetry() async {
    if (mounted) {
      context.read<PocoCubit>().updateMessage(
            "Pinging... Hello?",
            sequence: PocoExpressions.thinking,
          );
      setState(() {
        _showConfig = false;
      });
    }

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      context.read<PocoCubit>().updateMessage(
            "Home Sweet Localhost! We are safe.",
            sequence: PocoExpressions.happy,
          );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.goNamed('onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: AppPalette.primary.primaryColor,
                      fontSize: AppSizes.fontSmall,
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
                      if (_showConfig) ...[
                        VSpace.x4,
                        Container(
                          padding: EdgeInsets.all(AppSizes.space * 2),
                          color: Colors.black.withValues(alpha: 0.8),
                          child: Column(
                            children: [
                              TerminalInput(
                                controller: _urlController,
                                prompt: '\$',
                                onSubmitted: _handleConfigRetry,
                              ),
                            ],
                          ),
                        ),
                      ]
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

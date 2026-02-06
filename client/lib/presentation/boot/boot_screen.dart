import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/design_system/primitives/app_fonts.dart';
import 'package:test_app/design_system/primitives/app_palette.dart';
import 'package:test_app/design_system/primitives/app_sizes.dart';
import 'package:test_app/design_system/primitives/spacers.dart';
import 'package:test_app/presentation/core/widgets/poco_animator.dart';
import 'package:test_app/presentation/core/widgets/scanline_widget.dart';
import 'package:test_app/presentation/core/widgets/terminal_input.dart';
import 'package:test_app/presentation/core/widgets/ascii_art.dart';
import 'package:test_app/presentation/core/widgets/typewriter_text.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  // State Machine
  final bool _logsVisible = true;
  bool _logsDimmed = false;
  bool _pocoVisible = false;
  bool _showConfig = false;

  // Data
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _urlController =
      TextEditingController(text: 'http://127.0.0.1:8090');

  // Animation
  List<(String, int)> _pocoSequence = [(AppAscii.pocoSleepy, 1000)];
  final List<String> _pocoHistory = [];
  String _pocoMessage = "";

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
    // Schedule the "Director" cue: Wake up Poco at 2.5s mark
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _wakeUpPoco();
    });

    // Phase 1: Raw Logs
    String fileContent = await rootBundle.loadString('assets/boot_log.txt');
    final bootLogs = fileContent.split('\n');

    // Load ALL logs instantly
    if (mounted) {
      setState(() {
        _logs.addAll(bootLogs);
      });
    }

    // Scroll linearly (Cinematic credits style)
    // Wait one frame for layout to compute maxExtent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Calculate duration based on length to ensure constant speed
        // e.g., 20ms per line equivalent
        final duration = Duration(milliseconds: bootLogs.length * 20);

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: duration,
          curve: Curves.linear,
        );
      }
    });

    // Background noise will just append later
    // We can start it after the scroll finishes or just let it be
    Future.delayed(Duration(milliseconds: bootLogs.length * 20), () {
      if (mounted) _startBackgroundLogs();
    });
  }

  void _scrollToBottom() {
    // No-op now, handled by animation
  }

  void _wakeUpPoco() async {
    if (mounted) {
      setState(() {
        _logsDimmed = true;
        _pocoVisible = true;
        _pocoSequence = [
          (AppAscii.pocoSleepy, 1000),
          (AppAscii.pocoAwake, 200), // Blink
          (AppAscii.pocoSleepy, 200),
          (AppAscii.pocoAwake, 2000),
        ];
        _pocoMessage =
            "Hi! I'm Poco, your Private Operations Coding Officer representing the PocketCoder Initiative.";
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
        _scrollToBottom();
        i++;
      }
    }
  }

  Future<void> _checkConnection() async {
    // TODO: Real connection check here.
    bool connected = false; // Simulate fail for demo

    if (mounted) {
      setState(() {
        if (_pocoMessage.isNotEmpty) _pocoHistory.add(_pocoMessage);
        _pocoMessage = "Checking secure connection...";
      });
    }

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      if (connected) {
        // Success Path
        setState(() {
          if (_pocoMessage.isNotEmpty) _pocoHistory.add(_pocoMessage);
          _pocoSequence = [(AppAscii.pocoHappy, 2000)];
          _pocoMessage = "Systems nominal. I'm ready.";
        });
        await Future.delayed(const Duration(seconds: 2));
        context.goNamed('onboarding'); // Go to login
      } else {
        // Fail Path
        setState(() {
          if (_pocoMessage.isNotEmpty) _pocoHistory.add(_pocoMessage);
          _pocoSequence = [
            (AppAscii.pocoNervous, 500),
            (AppAscii.pocoPanic, 2000),
            (AppAscii.pocoNervous, 1000),
          ];
          _pocoMessage = "I lost the signal... Where is homeserver?";
          _showConfig = true;
        });
      }
    }
  }

  Future<void> _handleConfigRetry() async {
    setState(() {
      if (_pocoMessage.isNotEmpty) _pocoHistory.add(_pocoMessage);
      _showConfig = false;
      _pocoSequence = [(AppAscii.pocoThinking, 1000)];
      _pocoMessage = "Pinging... Hello?";
    });

    // TODO: Update ExternalModule with new URL

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        if (_pocoMessage.isNotEmpty) _pocoHistory.add(_pocoMessage);
        _pocoSequence = [(AppAscii.pocoHappy, 2000)];
        _pocoMessage = "Home Sweet Localhost! We are safe.";
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.goNamed('onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Hard Linux Black
      body: ScanlineWidget(
        child: Stack(
          children: [
            // Layer 1: The Raw Logs (Background)
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

            // Layer 2: Poco & Interaction (Foreground)
            if (_pocoVisible)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: 1.0,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PocoAnimator(
                          sequence: _pocoSequence,
                          fontSize: AppSizes.fontBig,
                        ),
                        VSpace.x4,
                        // Message Bubble
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: AppSizes.space * 2,
                              vertical: AppSizes.space),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                                color: AppPalette.primary.primaryColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._pocoHistory.map((msg) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      msg,
                                      style: TextStyle(
                                        fontFamily: AppFonts.bodyFamily,
                                        color: AppPalette.primary.textPrimary
                                            .withValues(alpha: 0.5),
                                        fontSize: AppSizes.fontStandard,
                                      ),
                                    ),
                                  )),
                              TypewriterText(
                                key: ValueKey(_pocoMessage),
                                text: _pocoMessage,
                                style: TextStyle(
                                  fontFamily: AppFonts.bodyFamily,
                                  color: AppPalette.primary.textPrimary,
                                  fontSize: AppSizes.fontStandard,
                                ),
                                speed: const Duration(milliseconds: 20),
                              ),
                            ],
                          ),
                        ),

                        // Config Input (Pop-up)
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
              ),
          ],
        ),
      ),
    );
  }
}

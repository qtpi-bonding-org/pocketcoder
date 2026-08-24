import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';

class MemoryDashboardScreen extends StatefulWidget {
  final PocketBase pocketBase;

  const MemoryDashboardScreen({super.key, required this.pocketBase});

  @override
  State<MemoryDashboardScreen> createState() => _MemoryDashboardScreenState();
}

class _MemoryDashboardScreenState extends State<MemoryDashboardScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          '${widget.pocketBase.baseURL}/api/pocketcoder/v1/proxy/observability/memory.sql',
        ),
        headers: {'Authorization': widget.pocketBase.authStore.token},
      );
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: 'POCKET MEMORY',
      activePillar: NavPillar.configure,
      showBack: true,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: context.colorScheme.surface,
                child: Center(child: TerminalLoadingIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

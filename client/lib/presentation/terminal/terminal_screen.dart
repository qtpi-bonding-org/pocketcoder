import 'package:flutter/material.dart';
import 'package:test_app/app/bootstrap.dart';
import 'package:test_app/domain/auth/i_auth_repository.dart';
import 'package:go_router/go_router.dart';
import '../../app_router.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/poco_animator.dart';
import '../core/widgets/terminal_footer.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final List<String> _logs = [
    'SYSTEM INITIALIZED',
    'GATEKEEPER ACTIVE',
    'WAITING FOR INPUT...',
  ];

  void _addLog(String message) {
    setState(() {
      _logs.add('>> $message');
      if (_logs.length > 20) _logs.removeAt(0);
    });
  }

  Future<void> _handleRegistration() async {
    _addLog('INITIATING DEVICE REGISTRATION...');
    final repo = getIt<IAuthRepository>();
    final success = await repo.registerDevice();

    if (success) {
      _addLog('DEVICE REGISTERED SUCCESSFULLY');
      _addLog('SECURE ENCLAVE KEY PERSISTED');
    } else {
      _addLog('REGISTRATION FAILED: CHECK AUTH STATE');
    }
  }

  Future<void> _handleSign() async {
    _addLog('REQUESTING SIGNATURE FOR CHALLENGE: [CHAL_821]');
    final repo = getIt<IAuthRepository>();
    final signature = await repo.signChallenge('CHAL_821');

    if (signature != null) {
      _addLog('SIGNATURE GENERATED: ${signature.substring(0, 10)}...');
      _addLog('IDENTITY VERIFIED VIA BIOMETRICS');
    } else {
      _addLog('SIGNATURE REJECTED OR ABORTED');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: ScanlineWidget(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildLogView(),
                ),
                const SizedBox(height: 24),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: TerminalFooter(
        actions: [
          TerminalAction(
            keyLabel: 'F1',
            label: 'ARTIFACTS',
            onTap: () => context.goNamed(RouteNames.artifact),
          ),
          TerminalAction(
            keyLabel: 'F3',
            label: 'SETTINGS',
            onTap: () => context.goNamed(RouteNames.settings),
          ),
          TerminalAction(
            keyLabel: 'F10',
            label: 'LOGOUT',
            onTap: () => context.goNamed(RouteNames.onboarding),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: PocoAnimator(fontSize: 20),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'POCKETCODER v1.0.4',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF39FF14),
                    letterSpacing: 2,
                  ),
            ),
            const Text(
              '[ ENCRYPTED CONNECTION ]',
              style: TextStyle(
                color: Color(0xFF39FF14),
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          width: double.infinity,
          color: const Color(0xFF39FF14).withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildLogView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border:
            Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.2)),
        color: Colors.black.withValues(alpha: 0.3),
      ),
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _logs[index],
              style: const TextStyle(
                color: Color(0xFF33FF33),
                fontSize: 14,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: _TerminalButton(
            label: 'REGISTER',
            onPressed: _handleRegistration,
            color: const Color(0xFF00FFFF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TerminalButton(
            label: 'AUTHORIZE',
            onPressed: _handleSign,
            color: const Color(0xFFFF00FF),
          ),
        ),
      ],
    );
  }
}

class _TerminalButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _TerminalButton({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: color),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

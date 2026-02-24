import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/bootstrap.dart';
import '../../application/billing/billing_cubit.dart';
import '../../application/billing/billing_state.dart';
import '../../domain/billing/billing_service.dart';
import '../core/widgets/ascii_art.dart';
import '../core/widgets/bios_frame.dart';
import '../core/widgets/scanline_widget.dart';
import '../core/widgets/terminal_footer.dart';
import '../core/widgets/terminal_button.dart';
import '../core/widgets/ui_flow_listener.dart';
import '../core/widgets/typewriter_text.dart';
import '../core/widgets/terminal_header.dart';
import '../core/widgets/terminal_loading_indicator.dart';
import '../core/widgets/bios_section.dart';
import '../../design_system/theme/app_theme.dart';

class PushNotificationsScreen extends StatelessWidget {
  const PushNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<BillingCubit>()..loadOfferings(),
      child: const PushNotificationsView(),
    );
  }
}

class PushNotificationsView extends StatelessWidget {
  const PushNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return UiFlowListener<BillingCubit, BillingState>(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ScanlineWidget(
          child: BiosFrame(
            title: 'RELAY CONFIG',
            child: Column(
              children: [
                TerminalHeader(title: 'PUSH NOTIFICATIONS'),
                VSpace.x2,
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSizes.space * 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: TypewriterText(
                            text: 'ESTABLISHING SECURE NOTIFICATION CHANNEL...',
                            speed: Duration(milliseconds: 30),
                          ),
                        ),
                        VSpace.x3,
                        BlocBuilder<BillingCubit, BillingState>(
                          builder: (context, state) {
                            if (state.isLoading) {
                              return const Center(
                                child: TerminalLoadingIndicator(
                                  label: 'SEARCHING FOR CONFIGURATION...',
                                ),
                              );
                            }

                            if (state.isPremium) {
                              return _buildActiveStatus(context, state);
                            }

                            return _buildSetupOptions(context, state);
                          },
                        ),
                        VSpace.x3,
                        Text(
                          'AVAILABILITY NOTICE:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                            package: 'pocketcoder_flutter',
                          ),
                        ),
                        Text(
                          'Push Notifications keep you synchronized with your agent\'s background reasoning. Select a service provider below to activate the relay.',
                          style: TextStyle(
                            fontSize: AppSizes.fontMini,
                            color: colors.onSurface.withValues(alpha: 0.7),
                            package: 'pocketcoder_flutter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TerminalFooter(
                  actions: [
                    TerminalAction(
                      label: 'RESTORE LICENSE',
                      onTap: () =>
                          context.read<BillingCubit>().restorePurchases(),
                    ),
                    TerminalAction(
                      label: 'BACK',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStatus(BuildContext context, BillingState state) {
    final colors = context.colorScheme;
    return Center(
      child: Column(
        children: [
          Text(
            '>>> STATUS: ACTIVE <<<',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              package: 'pocketcoder_flutter',
            ),
          ),
          VSpace.x2,
          AsciiFace.happy(fontSize: 24),
          VSpace.x2,
          const Text(
            'PUSH RELAY SUBSYSTEMS NOMINAL',
            style: TextStyle(package: 'pocketcoder_flutter'),
          ),
          VSpace.x1,
          Text(
            '1,000 NOTIFICATIONS PER DAY ALLOCATED',
            style: TextStyle(
              fontSize: AppSizes.fontMini,
              color: colors.onSurface.withValues(alpha: 0.7),
              package: 'pocketcoder_flutter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupOptions(BuildContext context, BillingState state) {
    // Filter packages based on type to separate FOSS and App
    final paywallPackages =
        state.packages.where((p) => !p.identifier.contains('foss')).toList();
    final fossPackages =
        state.packages.where((p) => p.identifier.contains('foss')).toList();

    return Column(
      children: [
        if (paywallPackages.isNotEmpty) ...[
          BiosSection(
            title: 'POCKETCODER PRO RELAY',
            child: Column(
              children:
                  paywallPackages.map((pkg) => _PackageCard(pkg: pkg)).toList(),
            ),
          ),
          VSpace.x1,
        ],
        if (fossPackages.isNotEmpty || paywallPackages.isEmpty) ...[
          BiosSection(
            title: 'SOVEREIGN NTFY SETUP',
            child: _NtfySetupCard(),
          ),
        ],
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  final BillingPackage pkg;

  const _PackageCard({required this.pkg});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.space),
      decoration: BoxDecoration(
        border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
        color: colors.primary.withValues(alpha: 0.05),
      ),
      padding: EdgeInsets.all(AppSizes.space * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRO SUBSCRIPTION',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  package: 'pocketcoder_flutter',
                  color: colors.onSurface,
                ),
              ),
              Text(
                pkg.priceString,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  package: 'pocketcoder_flutter',
                ),
              ),
            ],
          ),
          Text(
            pkg.description,
            style: TextStyle(
              fontSize: AppSizes.fontMini,
              package: 'pocketcoder_flutter',
            ),
          ),
          VSpace.x2,
          SizedBox(
            width: double.infinity,
            child: TerminalButton(
              label: 'ACTIVATE PRO RELAY',
              onTap: () =>
                  context.read<BillingCubit>().purchase(pkg.identifier),
            ),
          ),
        ],
      ),
    );
  }
}

class _NtfySetupCard extends StatelessWidget {
  const _NtfySetupCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.3)),
        color: colors.onSurface.withValues(alpha: 0.05),
      ),
      padding: EdgeInsets.all(AppSizes.space * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELF-HOSTED / PRIVATE PUSH',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              package: 'pocketcoder_flutter',
              color: colors.onSurface,
            ),
          ),
          Text(
            'Connect to your own NTFY server for free, unlimited notifications. No registration required.',
            style: TextStyle(
              fontSize: AppSizes.fontMini,
              package: 'pocketcoder_flutter',
            ),
          ),
          VSpace.x2,
          SizedBox(
            width: double.infinity,
            child: TerminalButton(
              label: 'CONFIGURE NTFY',
              isPrimary: false,
              onTap: () {
                // TODO: Open NTFY settings
              },
            ),
          ),
        ],
      ),
    );
  }
}

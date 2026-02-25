import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../domain/notifications/push_service.dart';
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
import '../core/widgets/terminal_header.dart';
import '../core/widgets/terminal_loading_indicator.dart';
import '../core/widgets/bios_section.dart';
import '../../design_system/theme/app_theme.dart';

class PermissionRelayScreen extends StatelessWidget {
  const PermissionRelayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<BillingCubit>()..loadOfferings(),
      child: const PermissionRelayView(),
    );
  }
}

class PermissionRelayView extends StatelessWidget {
  const PermissionRelayView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return UiFlowListener<BillingCubit, BillingState>(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ScanlineWidget(
          child: BiosFrame(
            title: 'PERMISSION RELAY',
            child: Column(
              children: [
                const TerminalHeader(title: 'PERMISSION RELAY'),
                VSpace.x2,
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSizes.space * 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlocBuilder<BillingCubit, BillingState>(
                          builder: (context, state) {
                            if (state.isLoading) {
                              return const Center(
                                child: TerminalLoadingIndicator(
                                  label: 'CHECKING RELAY STATUS...',
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
                          'FUNCTIONAL OVERVIEW:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                            package: 'pocketcoder_flutter',
                          ),
                        ),
                        Text(
                          'Permission Relays send agent intents to your device for remote authorization when you are away from the terminal.',
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
                      label: 'RESTORE',
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
            '>>> RELAY ACTIVE <<<',
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
            'SUBSYSTEMS NOMINAL',
            style: TextStyle(package: 'pocketcoder_flutter'),
          ),
          VSpace.x1,
          Text(
            'REMOTE AUTHORIZATION CAPACITY: UNLIMITED',
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
    final paywallPackages =
        state.packages.where((p) => !p.identifier.contains('foss')).toList();
    final fossPackages =
        state.packages.where((p) => p.identifier.contains('foss')).toList();

    return Column(
      children: [
        if (paywallPackages.isNotEmpty) ...[
          BiosSection(
            title: 'RELAY CONFIGURATION',
            child: Column(
              children:
                  paywallPackages.map((pkg) => _PackageCard(pkg: pkg)).toList(),
            ),
          ),
          VSpace.x1,
        ],
        if (fossPackages.isNotEmpty || paywallPackages.isEmpty) ...[
          BiosSection(
            title: 'NTFY RELAY',
            child: const _NtfySetupCard(),
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
                'PERMISSION RELAY',
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
              label: 'ACTIVATE RELAY',
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
            'NTFY RELAY',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              package: 'pocketcoder_flutter',
              color: colors.onSurface,
            ),
          ),
          Text(
            'Connect to your own NTFY server for free, unlimited relays without registration.',
            style: TextStyle(
              fontSize: AppSizes.fontMini,
              package: 'pocketcoder_flutter',
            ),
          ),
          VSpace.x2,
          SizedBox(
            width: double.infinity,
            child: TerminalButton(
              label: 'CONFIGURE',
              isPrimary: false,
              onTap: () {
                GetIt.I<PushService>().configure();
              },
            ),
          ),
        ],
      ),
    );
  }
}

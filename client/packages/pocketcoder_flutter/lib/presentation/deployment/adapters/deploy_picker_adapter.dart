import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/deployment/deploy_picker_cubit.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/presentation/billing/pro_paywall_screen.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_picker_screen.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

class DeployPickerAdapter
    extends CubitAdapter<DeployPickerCubit, DeployPickerState> {
  const DeployPickerAdapter({
    super.key,
    this.credentials,
    required this.onHasProAccess,
    this.onProviderSelected,
  });

  final DeployCredentials? credentials;

  /// Reads the current Pro entitlement without resolving billing from a view.
  final Future<bool> Function() onHasProAccess;
  final DeployProviderSelectionHandler? onProviderSelected;

  @override
  Widget buildAdapter(BuildContext context,
      CubitAdapterState<DeployPickerCubit, DeployPickerState> adapter) {
    final state = adapter.cubitField((value) => value);
    return UiFlowListener<DeployPickerCubit, DeployPickerState>(
      child: ValueListenableBuilder<DeployPickerState>(
        valueListenable: state,
        builder: (context, value, _) => DeployPickerView(
          options: value.options,
          onSelected: (option) => _select(context, option, adapter),
        ),
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    DeployOption option,
    CubitAdapterState<DeployPickerCubit, DeployPickerState> adapter,
  ) async {
    if (!option.isAvailable) return;
    final cubit = adapter.cubit;
    AppLogger.info('[Onboarding] deployment provider selection started', {
      'provider': option.id,
    });
    try {
      OnboardingLogger.event('deployment provider selected', {
        'provider': option.name,
        'requires_pro': option.requiresPro,
        'route': option.routePath ?? 'external'
      });
      if (option.requiresPro && !await onHasProAccess()) {
        if (!context.mounted) return;
        final unlocked = await context.push<bool>(
          AppRoutes.configurePaywall,
          extra: const ProPaywallRouteArguments(returnOnUnlock: true),
        );
        if (unlocked != true) return;
      }
      if (option.url != null) {
        final url = option.url;
        if (url == null) return;
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else if (option.routePath != null && context.mounted) {
        final routePath = option.routePath;
        if (routePath == null) return;
        final currentCredentials = credentials;
        if (currentCredentials == null) {
          context.pushNamed(RouteNames.onboardingDeploy, extra: option);
        } else if (onProviderSelected != null) {
          await onProviderSelected!(context, option, currentCredentials);
        } else {
          context.push(routePath, extra: currentCredentials);
        }
      }
    } catch (error, stackTrace) {
      AppLogger.error('[Onboarding] deployment provider selection failed',
          error, stackTrace);
      cubit.fail(error);
    }
  }
}

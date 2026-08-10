import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/application/deployment/deploy_picker_cubit.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_picker_screen.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class DeployPickerAdapter
    extends CubitAdapter<DeployPickerCubit, DeployPickerState> {
  const DeployPickerAdapter(
      {super.key, this.credentials, required this.onEnsureDeployAccess});

  final DeployCredentials? credentials;

  /// Returns whether the user has (or just gained) deploy access for
  /// [productId]. Injected so production supplies the real BillingService
  /// and Widgetbook supplies a fake, without either resolving GetIt inside
  /// this Adapter.
  final Future<bool> Function(String productId) onEnsureDeployAccess;

  @override
  Widget buildAdapter(BuildContext context,
      CubitAdapterState<DeployPickerCubit, DeployPickerState> adapter) {
    final state = adapter.cubitField((value) => value);
    return ValueListenableBuilder<DeployPickerState>(
      valueListenable: state,
      builder: (context, value, _) => DeployPickerView(
        options: value.options,
        credentials: credentials,
        onSelected: (option) => _select(context, option),
      ),
    );
  }

  Future<void> _select(BuildContext context, DeployOption option) async {
    if (!option.isAvailable) return;
    OnboardingLogger.event('deployment provider selected', {
      'provider': option.name,
      'requires_purchase': option.requiresPurchase,
      'route': option.routePath ?? 'external'
    });
    if (option.requiresPurchase && !kDebugMode) {
      if (!await onEnsureDeployAccess('pocketcoder_deploy_24h')) return;
    }
    if (option.url != null) {
      await launchUrl(Uri.parse(option.url!),
          mode: LaunchMode.externalApplication);
    } else if (option.routePath != null && context.mounted) {
      context.push(option.routePath!, extra: credentials);
    }
  }
}

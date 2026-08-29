import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/onboarding/create_account_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/presentation/deployment/server_credentials.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/create_account_view.dart';

// PocketBase's own migration rejects a seeded admin password under this
// length ("password: Must be at least 8 character(s)."), which otherwise
// only surfaces minutes later as an opaque release_install_failed deep into
// a live deploy -- confirmed live: this crash-loops the pocketbase
// container forever once a box has already been provisioned for it.
const _minimumPasswordLength = 8;

class CreateAccountAdapter
    extends CubitAdapter<CreateAccountCubit, CreateAccountState> {
  const CreateAccountAdapter({super.key, this.provider});

  final ProviderOption? provider;

  @override
  Widget buildAdapter(
      BuildContext context,
      CubitAdapterState<CreateAccountCubit, CreateAccountState>
          adapter) {
    final state = adapter.cubitField((value) => value);
    final cubit = context.read<CreateAccountCubit>();
    return ValueListenableBuilder<CreateAccountState>(
      valueListenable: state,
      builder: (context, value, _) => CreateAccountView(
        email: value.email,
        password: value.password,
        onEmailChanged: cubit.setEmail,
        onPasswordChanged: cubit.setPassword,
        passwordErrorText: value.password.isNotEmpty &&
                value.password.length < _minimumPasswordLength
            ? context.l10n.onboardingPasswordTooShort
            : null,
        isValid: value.email.trim().isNotEmpty &&
            value.password.length >= _minimumPasswordLength,
        onContinue: () {
          final current = cubit.state;
          if (current.email.trim().isEmpty ||
              current.password.length < _minimumPasswordLength) {
            return;
          }
          final credentials = ServerCredentials(
            email: current.email.trim(),
            password: current.password,
          );
          final providerRoute = provider?.routePath;
          if (providerRoute == null) {
            context.pushNamed(RouteNames.deploy, extra: credentials);
          } else {
            context.push(providerRoute, extra: credentials);
          }
        },
      ),
    );
  }
}

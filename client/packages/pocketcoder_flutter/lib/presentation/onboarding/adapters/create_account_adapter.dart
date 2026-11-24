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
import 'package:pocketcoder_flutter/support/validation/credential_rules.dart';

class CreateAccountAdapter
    extends CubitAdapter<CreateAccountCubit, CreateAccountState> {
  const CreateAccountAdapter({super.key, this.provider});

  final ProviderOption? provider;

  @override
  Widget buildAdapter(BuildContext context,
      CubitAdapterState<CreateAccountCubit, CreateAccountState> adapter) {
    final state = adapter.cubitField((value) => value);
    final cubit = context.read<CreateAccountCubit>();
    return ValueListenableBuilder<CreateAccountState>(
      valueListenable: state,
      builder: (context, value, _) => CreateAccountView(
        email: value.email,
        password: value.password,
        onEmailChanged: cubit.setEmail,
        onPasswordChanged: cubit.setPassword,
        emailErrorText: value.email.isEmpty
            ? null
            : switch (emailIssue(value.email)) {
                EmailIssue.surroundingWhitespace =>
                  context.l10n.onboardingEmailSurroundingWhitespace,
                EmailIssue.invalidFormat =>
                  context.l10n.onboardingEmailInvalidFormat,
                null => null,
              },
        passwordErrorText: value.password.isEmpty
            ? null
            : switch (newPasswordIssue(value.password)) {
                PasswordIssue.surroundingWhitespace =>
                  context.l10n.onboardingPasswordSurroundingWhitespace,
                PasswordIssue.tooShort =>
                  context.l10n.onboardingPasswordTooShort,
                PasswordIssue.tooLong => context.l10n.onboardingPasswordTooLong,
                null => null,
              },
        isValid: _isValid(value),
        onContinue: () {
          final current = cubit.state;
          if (!_isValid(current)) return;
          final credentials = ServerCredentials(
            email: current.email,
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

  static bool _isValid(CreateAccountState state) =>
      emailIssue(state.email) == null &&
      newPasswordIssue(state.password) == null;
}

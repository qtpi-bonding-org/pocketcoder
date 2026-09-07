import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_mode_rules_cubit.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'adapters/permission_mode_rules_adapter.dart';

class PermissionModeRulesScreen extends StatelessWidget {
  const PermissionModeRulesScreen({super.key, required this.mode});

  final PermissionMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<PermissionModeRulesCubit>()..watchRules(mode.id),
      child: PermissionModeRulesAdapter(mode: mode),
    );
  }
}

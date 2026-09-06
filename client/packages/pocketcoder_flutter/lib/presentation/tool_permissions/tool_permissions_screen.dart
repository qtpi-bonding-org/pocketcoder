import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

import 'adapters/tool_permissions_adapter.dart';

class ToolPermissionsScreen extends StatelessWidget {
  const ToolPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ToolPermissionsCubit>()..watchRules(),
      child: const ToolPermissionsAdapter(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_cubit.dart';
import 'adapters/permission_modes_adapter.dart';

class PermissionModesScreen extends StatelessWidget {
  const PermissionModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PermissionModesCubit>()..watchModes(),
      child: const PermissionModesAdapter(),
    );
  }
}

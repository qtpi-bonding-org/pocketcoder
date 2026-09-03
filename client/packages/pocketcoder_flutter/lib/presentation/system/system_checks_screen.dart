import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/system/health_cubit.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'adapters/system_checks_adapter.dart';

class SystemChecksScreen extends StatelessWidget {
  const SystemChecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<HealthCubit>()..watchHealth(),
      child: const SystemChecksAdapter(),
    );
  }
}

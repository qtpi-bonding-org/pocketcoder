// lib/presentation/errors/error_box_page_builder.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_cubit.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_diagnostics_cubit.dart';
import 'error_inbox_screen.dart';

class PocketCoderErrorBoxPageBuilder extends StatelessWidget {
  const PocketCoderErrorBoxPageBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ErrorInboxCubit()..loadErrors(),
        ),
        BlocProvider(create: (_) => ErrorInboxDiagnosticsCubit()),
      ],
      child: const ErrorInboxScreen(),
    );
  }
}

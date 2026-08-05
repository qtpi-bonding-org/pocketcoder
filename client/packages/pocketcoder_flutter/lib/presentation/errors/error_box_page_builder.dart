// lib/presentation/errors/error_box_page_builder.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_diagnostics_cubit.dart';
import 'error_inbox_screen.dart';

class PocketCoderErrorBoxPageBuilder extends ErrorBoxPageBuilder {
  const PocketCoderErrorBoxPageBuilder();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ErrorBoxPageCubit()..loadErrors(),
        ),
        BlocProvider(create: (_) => ErrorInboxDiagnosticsCubit()),
      ],
      child: const ErrorInboxScreen(),
    );
  }
}

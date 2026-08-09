// lib/presentation/errors/error_box_page_builder.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_cubit.dart';
import 'adapters/error_inbox_adapter.dart';

class PocketCoderErrorBoxPageBuilder extends StatelessWidget {
  const PocketCoderErrorBoxPageBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ErrorInboxCubit()..loadErrors(),
      child: const ErrorInboxAdapter(),
    );
  }
}

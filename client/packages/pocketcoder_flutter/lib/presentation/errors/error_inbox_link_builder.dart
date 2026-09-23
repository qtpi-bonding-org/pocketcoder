import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_cubit.dart';
import 'adapters/error_inbox_link_adapter.dart';

class ErrorInboxLinkBuilder extends StatelessWidget {
  const ErrorInboxLinkBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ErrorInboxCubit(watchStorage: true)..loadErrors(),
      child: const ErrorInboxLinkAdapter(),
    );
  }
}

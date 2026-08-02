// lib/presentation/errors/error_box_page_builder.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'error_inbox_screen.dart';

class PocketCoderErrorBoxPageBuilder extends ErrorBoxPageBuilder {
  const PocketCoderErrorBoxPageBuilder();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ErrorBoxPageCubit()..loadErrors(),
      child: const ErrorInboxScreen(),
    );
  }
}
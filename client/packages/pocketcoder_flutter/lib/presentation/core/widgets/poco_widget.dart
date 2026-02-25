import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'poco_bubble.dart';

/// The "Smart" mascot widget.
/// It listens to the global [PocoCubit] and renders the [PocoBubble].
/// Place this anywhere you want Poco to appear and react to system events.
class PocoWidget extends StatelessWidget {
  final double? pocoSize;
  final TextAlign textAlign;

  const PocoWidget({
    super.key,
    this.pocoSize,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PocoCubit, PocoState>(
      builder: (context, state) {
        return PocoBubble(
          message: state.message,
          sequence: state.sequence,
          history: state.history,
          pocoSize: pocoSize,
          textAlign: textAlign,
        );
      },
    );
  }
}

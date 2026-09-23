import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_cubit.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_state.dart';
import 'package:pocketcoder_flutter/presentation/errors/widgets/error_inbox_link.dart';

class ErrorInboxLinkAdapter
    extends CubitAdapter<ErrorInboxCubit, ErrorInboxState> {
  const ErrorInboxLinkAdapter({super.key});

  static int _selectCount(ErrorInboxState state) => state.errors.length;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ErrorInboxCubit, ErrorInboxState> adapter,
  ) {
    final count = adapter.cubitField(_selectCount);
    return ValueListenableBuilder<int>(
      valueListenable: count,
      builder: (context, value, _) => ErrorInboxLink(
        count: value,
        onTap: () => _openInbox(context, adapter.cubit),
      ),
    );
  }

  Future<void> _openInbox(BuildContext context, ErrorInboxCubit cubit) async {
    await context.pushNamed(RouteNames.statusErrors);
    if (!cubit.isClosed) await cubit.loadErrors();
  }
}

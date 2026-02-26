import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import '../../app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/application/chat/communication_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/communication_state.dart';

class ArtifactScreen extends StatefulWidget {
  final String? initialPath;

  const ArtifactScreen({super.key, this.initialPath});

  @override
  State<ArtifactScreen> createState() => _ArtifactScreenState();
}

class _ArtifactScreenState extends State<ArtifactScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context
            .read<CommunicationCubit>()
            .fetchArtifactContent(widget.initialPath!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return UiFlowListener<CommunicationCubit, CommunicationState>(
      child: Scaffold(
        backgroundColor: colors.surface,
        body: ScanlineWidget(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.space * 2),
              child: Column(
                children: [
                  const TerminalHeader(title: 'SOURCE OUTPUT MANIFEST'),
                  VSpace.x2,
                  Expanded(
                    child: BlocBuilder<CommunicationCubit, CommunicationState>(
                      builder: (context, state) {
                        return BiosFrame(
                          title: state.currentArtifactPath ??
                              'DELIVERABLES & ARTIFACTS',
                          child: _buildArtifactContent(context, state),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: TerminalFooter(
          actions: [
            TerminalAction(
              label: 'DASHBOARD',
              onTap: () => context.goNamed(RouteNames.home),
            ),
            TerminalAction(
              label: 'CLEAR',
              onTap: () => context.read<CommunicationCubit>().clearArtifact(),
            ),
            TerminalAction(
              label: 'BACK',
              onTap: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtifactContent(BuildContext context, CommunicationState state) {
    final colors = context.colorScheme;

    if (state.currentArtifactPath == null) {
      return Center(
        child: BiosSection(
          title: 'REGISTRY STATUS',
          child: Column(
            children: [
              Text(
                'NO ARTIFACT SELECTED.',
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '>> SELECT FROM CHAT TO VIEW',
                style: TextStyle(
                  fontFamily: AppFonts.bodyFamily,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontSize: AppSizes.fontMini,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoading) {
      return Center(
        child: Text(
          'FETCHING DATA...',
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.primary,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.space),
      child: Text(
        state.currentArtifactContent ?? 'EMPTY FILE',
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: colors.onSurface,
          fontSize: AppSizes.fontStandard,
        ),
      ),
    );
  }
}

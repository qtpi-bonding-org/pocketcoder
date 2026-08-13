import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/skills/widgets/skills_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

@wb.UseCase(name: 'empty state', type: SkillsView)
Widget skillsEmpty(BuildContext context) => _app(SkillsView(
      data: const SkillsViewData(),
      onAdd: () {},
      onEdit: (_) {},
      onDelete: (_) {},
    ));

@wb.UseCase(name: 'global and project skills', type: SkillsView)
Widget skillsPopulated(BuildContext context) => _app(SkillsView(
      data: SkillsViewData(skills: const [
        Skill(
            id: 'deploy',
            name: 'deploy',
            description: 'Deploy the current project.',
            content: 'run deploy'),
        Skill(
            id: 'review',
            name: 'review',
            description: 'Review changes before merging.',
            content: 'review diff',
            metadata: {'projectDir': '/workspace/project'}),
      ]),
      onAdd: () {},
      onEdit: (_) {},
      onDelete: (_) {},
    ));

@wb.UseCase(name: 'loading', type: SkillsView)
Widget skillsLoading(BuildContext context) => _app(SkillsView(
      data: const SkillsViewData(isLoading: true),
      onAdd: () {},
      onEdit: (_) {},
      onDelete: (_) {},
    ));

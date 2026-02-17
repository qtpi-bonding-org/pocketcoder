import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_app/app/bootstrap.dart';
import 'package:test_app/application/whitelist/whitelist_cubit.dart';
import 'package:test_app/domain/whitelist/whitelist_target.dart';

class WhitelistScreen extends StatelessWidget {
  const WhitelistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<WhitelistCubit>()..load(),
      child: const WhitelistView(),
    );
  }
}

class WhitelistView extends StatelessWidget {
  const WhitelistView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Whitelist Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Actions'),
              Tab(text: 'Targets'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ActionsTab(),
            TargetsTab(),
          ],
        ),
        floatingActionButton: Builder(
          builder: (ctx) {
            // Context here is within TabBarView? No, need to check tab index.
            // Actually FAB is global to Scaffold.
            // Better to put FAB inside tabs or use a listener.
            // For simplicity, let's put "Add" buttons inside the tabs themselves (as headers or FABs there).
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class ActionsTab extends StatelessWidget {
  const ActionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WhitelistCubit, WhitelistState>(
      builder: (context, state) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              state.maybeWhen(
                loaded: (targets, _) => _showAddActionDialog(context, targets),
                orElse: () {},
              );
            },
            child: const Icon(Icons.add),
          ),
          body: state.maybeWhen(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (msg) => Center(child: Text('Error: $msg')),
            loaded: (targets, actions) {
              if (actions.isEmpty) {
                return const Center(
                  child: Text('No actions defined. Add one!'),
                );
              }
              return ListView.builder(
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return ListTile(
                    title: Text(action.command),
                    subtitle: Text(action.target?.name ?? 'No Target'),
                    trailing: Switch(
                      value: action.isActive,
                      onChanged: (val) => context
                          .read<WhitelistCubit>()
                          .toggleAction(action.id, val),
                    ),
                    onLongPress: () =>
                        context.read<WhitelistCubit>().deleteAction(action.id),
                  );
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  void _showAddActionDialog(
      BuildContext context, List<WhitelistTarget> targets) {
    final commandController = TextEditingController();
    String? selectedTargetId;
    if (targets.isNotEmpty) selectedTargetId = targets.first.id;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Action Rule'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: commandController,
                decoration: const InputDecoration(
                    labelText: 'Command (e.g. git clone)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTargetId,
                items: targets
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => selectedTargetId = val),
                decoration: const InputDecoration(labelText: 'Target'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (commandController.text.isNotEmpty &&
                  selectedTargetId != null) {
                context.read<WhitelistCubit>().createAction(
                      commandController.text,
                      selectedTargetId!,
                    );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class TargetsTab extends StatelessWidget {
  const TargetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WhitelistCubit, WhitelistState>(
      builder: (context, state) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTargetDialog(context),
            child: const Icon(Icons.add),
          ),
          body: state.maybeWhen(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (msg) => Center(child: Text('Error: $msg')),
            loaded: (targets, actions) {
              if (targets.isEmpty) {
                return const Center(child: Text('No targets defined. Add one!'));
              }
              return ListView.builder(
                itemCount: targets.length,
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return ListTile(
                    title: Text(target.name),
                    subtitle: Text('${target.type}: ${target.pattern}'),
                    onLongPress: () =>
                        context.read<WhitelistCubit>().deleteTarget(target.id),
                  );
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  void _showAddTargetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final patternController = TextEditingController();
    String type = 'domain';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Whitelist Target'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Name (e.g. GitHub)'),
              ),
              TextField(
                controller: patternController,
                decoration: const InputDecoration(
                    labelText: 'Pattern (e.g. github.com/*)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: ['domain', 'repo', 'path']
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => type = val!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  patternController.text.isNotEmpty) {
                context.read<WhitelistCubit>().createTarget(
                      nameController.text,
                      patternController.text,
                      type,
                    );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

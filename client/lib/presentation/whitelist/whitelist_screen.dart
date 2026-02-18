import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app/bootstrap.dart';
import '../../application/whitelist/whitelist_cubit.dart';
import '../../domain/whitelist/whitelist_target.dart';

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
                loaded: (_, actions) => _showAddActionDialog(context),
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
                    title: Text(action.permission),
                    subtitle: Text('${action.kind}: ${action.value}'),
                    trailing: Switch(
                      value: action.active,
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

  void _showAddActionDialog(BuildContext context) {
    final permissionController = TextEditingController();
    final valueController = TextEditingController();
    String kind = 'pattern';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Action Rule'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: permissionController,
                decoration: const InputDecoration(
                    labelText: 'Permission (e.g. bash.run)'),
              ),
              TextField(
                controller: valueController,
                decoration:
                    const InputDecoration(labelText: 'Value (e.g. git *)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: kind,
                items: ['pattern', 'strict']
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => kind = val!),
                decoration: const InputDecoration(labelText: 'Kind'),
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
              if (permissionController.text.isNotEmpty) {
                context.read<WhitelistCubit>().createAction(
                      permissionController.text,
                      kind: kind,
                      value: valueController.text,
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
                return const Center(
                    child: Text('No targets defined. Add one!'));
              }
              return ListView.builder(
                itemCount: targets.length,
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return ListTile(
                    title: Text(target.name),
                    subtitle: Text(target.pattern),
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

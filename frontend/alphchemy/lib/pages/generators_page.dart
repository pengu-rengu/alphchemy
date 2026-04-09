import "package:alphchemy/blocs/generators_bloc.dart";
import "package:alphchemy/model/generator_summary.dart";
import "package:alphchemy/pages/editor_page.dart";
import "package:alphchemy/repositories/generator_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:uuid/uuid.dart";

const _uuid = Uuid();

class GeneratorsPage extends StatelessWidget {
  const GeneratorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<GeneratorsBloc, GeneratorsState>(
        builder: (context, state) {
          if (state is GeneratorsError) {
            return Center(child: Text(state.message));
          }
          if (state is! GeneratorsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return GeneratorsList(generators: state.generators);
        }
      )
    );
  }
}

class GeneratorsList extends StatelessWidget {
  final List<GeneratorSummary> generators;

  const GeneratorsList({super.key, required this.generators});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GeneratorsHeader(),
        const Divider(height: 1),
        Expanded(child: generators.isEmpty
          ? const Center(child: Text("No generators yet"))
        : ListView.builder(
            itemCount: generators.length,
            itemBuilder: (context, i) {
              return GeneratorListTile(summary: generators[i]);
            }
          )
        )
      ]
    );
  }
}

class _GeneratorsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text("Generators", style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          FilledButton.icon(
            onPressed: () async {
              final id = _uuid.v4();
              final repository = context.read<GeneratorRepository>();
              final route = MaterialPageRoute<void>(
                builder: (_) => EditorPage(
                  generatorId: id,
                  repository: repository
                )
              );

              context.read<GeneratorsBloc>().add(CreateGenerator(id: id));
              await Navigator.of(context).push(route);
              if (!context.mounted) {
                return;
              }
              context.read<GeneratorsBloc>().add(const LoadGenerators());
            },
            icon: const Icon(Icons.add),
            label: const Text("New Generator")
          )
        ]
      )
    );
  }
}

class GeneratorListTile extends StatelessWidget {
  final GeneratorSummary summary;

  const GeneratorListTile({
    super.key,
    required this.summary
  });

  @override
  Widget build(BuildContext context) {
    final dateText = _formatDate(summary.createdAt);
    final repository = context.read<GeneratorRepository>();
    final route = MaterialPageRoute<void>(
      builder: (_) => EditorPage(
        generatorId: summary.id,
        repository: repository
      )
    );

    return ListTile(
      title: Text(summary.title),
      subtitle: Text(dateText),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteGenerator(context)
      ),
      onTap: () async {
        await Navigator.of(context).push(route);
        if (!context.mounted) {
          return;
        }
        context.read<GeneratorsBloc>().add(const LoadGenerators());
      }
    );
  }

  Future<void> _deleteGenerator(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Generator"),
        content: Text("Delete \"${summary.title}\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete")
          )
        ]
      )
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    context.read<GeneratorsBloc>().add(DeleteGenerator(id: summary.id));
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, "0");
    final day = date.day.toString().padLeft(2, "0");
    return "$year-$month-$day";
  }
}

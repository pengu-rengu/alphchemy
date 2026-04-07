import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/model/generator/param_space.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:alphchemy/widgets/synced_text_field.dart";

class ParamSidebar extends StatelessWidget {
  const ParamSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state is! EditorLoaded) return const SizedBox();
        final paramEntries = state.paramSpace.searchSpace.entries.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ParamSidebarHeader(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                itemCount: paramEntries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 5),
                itemBuilder: (context, idx) {
                  final paramEntry = paramEntries[idx];

                  return ParamCard(
                    name: paramEntry.key,
                    param: paramEntry.value,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ParamSidebarHeader extends StatelessWidget {
  const ParamSidebarHeader({super.key});

  String _uniqueName(Map<String, Param> existing) {
    for (var i = 0; ; i++) {
      final name = "param_$i";
      if (!existing.containsKey(name)) return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Parameters",
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
            padding: EdgeInsets.zero,
            onPressed: () {
              final bloc = context.read<EditorBloc>();

              final name = _uniqueName((bloc.state as EditorLoaded).paramSpace.searchSpace);
              final param = Param(
                type: ParamType.floatType,
                values: [],
              );

              final event = AddParam(name: name, param: param);
              bloc.add(event);
            },
          ),
        ],
      ),
    );
  }
}

class ParamCard extends StatelessWidget {
  final String name;
  final Param param;

  const ParamCard({super.key, required this.name, required this.param});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ParamNameRow(name: name),
          const SizedBox(height: 4),
          ParamTypeRow(name: name, param: param),
          const SizedBox(height: 4),
          ParamValuesRow(name: name, param: param),
        ],
      ),
    );
  }
}

class ParamNameRow extends StatelessWidget {
  final String name;

  const ParamNameRow({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 14),
          constraints: const BoxConstraints(maxHeight: 24, maxWidth: 24),
          padding: EdgeInsets.zero,
          onPressed: () async {
            final newName = await showDialog<String>(
              context: context,
              builder: (_) => RenameParamDialog(name: name),
            );

            if (!context.mounted) {
              return;
            }
            if (newName == null) {
              return;
            }

            final event = RenameParam(oldName: name, newName: newName);
            context.read<EditorBloc>().add(event);
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete, size: 16),
          constraints: const BoxConstraints(maxHeight: 24, maxWidth: 24),
          padding: EdgeInsets.zero,
          onPressed: () {
            final event = RemoveParam(name: name);
             context.read<EditorBloc>().add(event);
          },
        ),
      ],
    );
  }
}

class RenameParamDialog extends StatelessWidget {
  final String name;

  const RenameParamDialog({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: name);
    return AlertDialog(
      title: const Text("Rename Parameter"),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: "Name"),
        onSubmitted: (_) => _submit(context, controller),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => _submit(context, controller),
          child: const Text("Save"),
        ),
      ],
    );
  }

  void _submit(BuildContext context, TextEditingController controller) {
    final newName = controller.text.trim();
    if (newName.isEmpty) {
      return;
    }

    Navigator.of(context).pop(newName);
  }
}

class ParamTypeRow extends StatelessWidget {
  final String name;
  final Param param;

  const ParamTypeRow({super.key, required this.name, required this.param});

  static String typeLabel(ParamType type) {
    switch (type) {
      case ParamType.intType:
        return "int";
      case ParamType.floatType:
        return "float";
      case ParamType.stringType:
        return "string";
      case ParamType.boolType:
        return "bool";
      case ParamType.intListType:
        return "int list";
      case ParamType.stringListType:
        return "string list";
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: DropdownButton<ParamType>(
        value: param.type,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox(),
        items: ParamType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(
              ParamTypeRow.typeLabel(type),
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val == null) return;
          final editorBloc = context.read<EditorBloc>();
          final event = UpdateParamType(name: name, type: val);
          editorBloc.add(event);
        },
      ),
    );
  }
}

class ParamValuesRow extends StatelessWidget {
  final String name;
  final Param param;

  const ParamValuesRow({super.key, required this.name, required this.param});

  String _hintText() {
    if (!param.type.isListType) return "comma-separated values";
    return "comma-separated items; semicolon-separated lists";
  }

  @override
  Widget build(BuildContext context) {
    final display = formatParamValuesText(param.values, param.type);
    return SizedBox(
      height: 24,
      child: SyncedTextField(
        text: display,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: _hintText(),
          hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
        ),
        onChanged: (val) {
          final editorBloc = context.read<EditorBloc>();
          final event = UpdateParamValues(name: name, text: val);
          editorBloc.add(event);
        },
      ),
    );
  }
}

import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ParamSidebar extends StatelessWidget {
  const ParamSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        final params = state.params.values.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ParamSidebarHeader(),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 8),
                itemCount: params.length,
                separatorBuilder: (_, _) => SizedBox(height: 4),
                itemBuilder: (context, idx) {
                  return ParamCard(param: params[idx]);
                }
              )
            )
          ]
        );
      }
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
      padding: EdgeInsets.fromLTRB(12, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Parameters",
              style: Theme.of(context).textTheme.titleSmall
            )
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18),
            constraints: BoxConstraints(maxHeight: 28, maxWidth: 28),
            padding: EdgeInsets.zero,
            onPressed: () {
              final editorBloc = context.read<EditorBloc>();
              final name = _uniqueName(editorBloc.state.params);
              final param = Param(
                name: name,
                type: ParamType.floatType,
                values: []
              );
              editorBloc.add(AddParam(param: param));
            }
          )
        ]
      )
    );
  }
}

class ParamCard extends StatelessWidget {
  final Param param;

  const ParamCard({super.key, required this.param});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ParamNameRow(param: param),
          SizedBox(height: 4),
          ParamTypeRow(param: param),
          SizedBox(height: 4),
          ParamValuesRow(param: param)
        ]
      )
    );
  }
}

class ParamNameRow extends StatelessWidget {
  final Param param;

  const ParamNameRow({super.key, required this.param});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            param.name,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis
          )
        ),
        IconButton(
          icon: Icon(Icons.edit, size: 14),
          constraints: BoxConstraints(maxHeight: 24, maxWidth: 24),
          padding: EdgeInsets.zero,
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => RenameParamDialog(param: param)
            );
          }
        ),
        SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.delete, size: 16),
          constraints: BoxConstraints(maxHeight: 24, maxWidth: 24),
          padding: EdgeInsets.zero,
          onPressed: () {
            final editorBloc = context.read<EditorBloc>();
            editorBloc.add(RemoveParam(name: param.name));
          }
        )
      ]
    );
  }
}

class RenameParamDialog extends StatelessWidget {
  final Param param;

  const RenameParamDialog({super.key, required this.param});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: param.name);
    return AlertDialog(
      title: Text("Rename Parameter"),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: "Name"),
        onSubmitted: (_) => _submit(context, controller)
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel")
        ),
        TextButton(
          onPressed: () => _submit(context, controller),
          child: Text("Save")
        )
      ]
    );
  }

  void _submit(BuildContext context, TextEditingController controller) {
    final val = controller.text.trim();
    if (val.isEmpty) return;
    final updated = Param(name: val, type: param.type, values: param.values);
    final editorBloc = context.read<EditorBloc>();
    editorBloc.add(UpdateParam(oldName: param.name, param: updated));
    Navigator.of(context).pop();
  }
}

class ParamTypeRow extends StatelessWidget {
  final Param param;

  const ParamTypeRow({super.key, required this.param});

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
        underline: SizedBox(),
        items: ParamType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(
              ParamTypeRow.typeLabel(type),
              style: TextStyle(fontSize: 12)
            )
          );
        }).toList(),
        onChanged: (val) {
          if (val == null) return;
          final updated = Param(name: param.name, type: val, values: []);
          final editorBloc = context.read<EditorBloc>();
          editorBloc.add(UpdateParam(oldName: param.name, param: updated));
        }
      )
    );
  }
}

class ParamValuesRow extends StatelessWidget {
  final Param param;

  const ParamValuesRow({super.key, required this.param});

  @override
  Widget build(BuildContext context) {
    final display = param.values.map((val) => val.toString()).join(", ");
    return SizedBox(
      height: 24,
      child: TextField(
        controller: TextEditingController(text: display),
        style: TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: "comma-separated values",
          hintStyle: TextStyle(fontSize: 11, color: Colors.white24)
        ),
        onSubmitted: (val) {
          final parsed = _parseValues(val, param.type);
          final updated = Param(
            name: param.name,
            type: param.type,
            values: parsed
          );
          final editorBloc = context.read<EditorBloc>();
          editorBloc.add(UpdateParam(oldName: param.name, param: updated));
        }
      )
    );
  }
}

List<dynamic> _parseValues(String input, ParamType type) {
  final parts = input.split(",").map((str) => str.trim()).where((str) {
    return str.isNotEmpty;
  });

  switch (type) {
    case ParamType.intType:
      return parts.map((str) => int.tryParse(str)).whereType<int>().toList();
    case ParamType.floatType:
      return parts.map((str) => double.tryParse(str)).whereType<double>().toList();
    case ParamType.stringType:
      return parts.toList();
    case ParamType.boolType:
      return parts.map(_parseBool).whereType<bool>().toList();
    case ParamType.intListType:
      return parts.toList();
  }
}

bool? _parseBool(String str) {
  if (str == "true") return true;
  if (str == "false") return false;
  return null;
}

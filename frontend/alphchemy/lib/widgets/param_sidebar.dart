import "package:alphchemy/blocs/param_space_bloc.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ParamSidebar extends StatelessWidget {
  const ParamSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ParamSpaceBloc, ParamSpaceState>(
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
              final bloc = context.read<ParamSpaceBloc>();
              final name = _uniqueName(bloc.state.params);
              final param = ParamDef(
                name: name,
                type: ParamType.floatType,
                values: []
              );
              bloc.add(AddParam(param: param));
            }
          )
        ]
      )
    );
  }
}

String _uniqueName(Map<String, ParamDef> existing) {
  for (var i = 0; ; i++) {
    final name = "param_$i";
    if (!existing.containsKey(name)) return name;
  }
}

class ParamCard extends StatelessWidget {
  final ParamDef param;

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
  final ParamDef param;

  const ParamNameRow({super.key, required this.param});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 24,
            child: TextField(
              controller: TextEditingController(text: param.name),
              style: TextStyle(fontSize: 12),
              onSubmitted: (val) {
                if (val.isEmpty) return;
                final bloc = context.read<ParamSpaceBloc>();
                final updated = ParamDef(
                  name: val,
                  type: param.type,
                  values: param.values
                );
                bloc.add(UpdateParam(oldName: param.name, param: updated));
              }
            )
          )
        ),
        SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.delete, size: 16),
          constraints: BoxConstraints(maxHeight: 24, maxWidth: 24),
          padding: EdgeInsets.zero,
          onPressed: () {
            final bloc = context.read<ParamSpaceBloc>();
            bloc.add(RemoveParam(name: param.name));
          }
        )
      ]
    );
  }
}

class ParamTypeRow extends StatelessWidget {
  final ParamDef param;

  const ParamTypeRow({super.key, required this.param});

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
            child: Text(_typeLabel(type), style: TextStyle(fontSize: 12))
          );
        }).toList(),
        onChanged: (val) {
          if (val == null) return;
          final bloc = context.read<ParamSpaceBloc>();
          final updated = ParamDef(
            name: param.name,
            type: val,
            values: []
          );
          bloc.add(UpdateParam(oldName: param.name, param: updated));
        }
      )
    );
  }
}

String _typeLabel(ParamType type) {
  switch (type) {
    case ParamType.intType: return "int";
    case ParamType.floatType: return "float";
    case ParamType.stringType: return "string";
    case ParamType.boolType: return "bool";
    case ParamType.intListType: return "int list";
  }
}

class ParamValuesRow extends StatelessWidget {
  final ParamDef param;

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
          final bloc = context.read<ParamSpaceBloc>();
          final updated = ParamDef(
            name: param.name,
            type: param.type,
            values: parsed
          );
          bloc.add(UpdateParam(oldName: param.name, param: updated));
        }
      )
    );
  }
}

List<dynamic> _parseValues(String input, ParamType type) {
  final parts = input.split(",")
      .map((str) => str.trim())
      .where((str) => str.isNotEmpty);
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

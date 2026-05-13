import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";

class NodeTextField extends StatelessWidget {
  final String label;
  final String field;

  const NodeTextField({super.key, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeDataState>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = bloc.nodeData.formatField(field);

        return Row(children: [
          SizedBox(width: 200, child: NormalText(label)),
          Expanded(child: SyncedTextField(
            text: value,
            onChanged: (val) {
              bloc.add(UpdateNodeField(field: field, text: val));
            }
          ))
        ]);
      }
    );
  }
}

class NodeDropdown<T> extends StatelessWidget {
  final String label;
  final String field;
  final List<T> options;
  final String Function(T) optionLabel;

  const NodeDropdown({super.key, required this.label, required this.field, required this.options, required this.optionLabel});

  T? _selectedValue(NodeDataBloc bloc) {
    final currentText = bloc.nodeData.formatField(field);
    for (final option in options) {
      final optionText = optionLabel(option);
      if (optionText != currentText) continue;
      return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeDataState>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = _selectedValue(bloc);

        return Row(children: [
          SizedBox(width: 200, child: NormalText(label)),
          Expanded(child: DropdownButton<T>( // change to DropdownMenu
            key: ValueKey<String>("node_dropdown_$field"),
            value: value,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox(),
            items: options.map((option) {
              final label = optionLabel(option);
              return DropdownMenuItem<T>(
                value: option,
                child: NormalText(label)
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              bloc.add(UpdateNodeFieldTyped(field: field, value: val));
            }
          ))
        ]);
      }
    );
  }
}

class NodeBoolDropdown extends StatelessWidget {
  final String label;
  final String field;

  const NodeBoolDropdown({super.key, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<bool>(
      label: label,
      field: field,
      options: const [true, false],
      optionLabel: (option) => option.toString()
    );
  }
}

class NodeFields extends StatelessWidget {
  static const _fieldGap = SizedBox(height: 2);
  final NodeData nodeData;

  const NodeFields({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    final fields = nodeData.fields;
    if (fields.isEmpty) return const SizedBox();

    final children = <Widget>[const SizedBox(height: 5)];

    for (var i = 0; i < fields.length; i++) {
      if (i > 0) children.add(_fieldGap);
      children.add(fields[i]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
    );
  }
}

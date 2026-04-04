import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:alphchemy/widgets/synced_text_field.dart";

class NodeTextField extends StatelessWidget {
  final String label;
  final String fieldKey;

  const NodeTextField({super.key, required this.label, required this.fieldKey});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NodeDataBloc>();
    final value = bloc.node.data.formatField(fieldKey);
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label)),
        Expanded(
          child: SizedBox(
            height: 24,
            child: SyncedTextField(
              text: value,
              onChanged: (val) {
                bloc.add(UpdateNodeField(fieldKey: fieldKey, text: val));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class NodeDropdown<T> extends StatelessWidget {
  final String label;
  final String fieldKey;
  final List<T> options;
  final String Function(T) labelFor;

  const NodeDropdown({
    super.key,
    required this.label,
    required this.fieldKey,
    required this.options,
    required this.labelFor,
  });

  T? _selectedValue(NodeDataBloc bloc) {
    final currentText = bloc.node.data.formatField(fieldKey);
    for (final option in options) {
      final optionText = labelFor(option);
      if (optionText != currentText) continue;
      return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NodeDataBloc>();
    final value = _selectedValue(bloc);
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label)),
        Expanded(
          child: SizedBox(
            height: 24,
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox(),
              items: options.map((opt) {
                return DropdownMenuItem<T>(
                  value: opt,
                  child: Text(labelFor(opt)),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final bloc = context.read<NodeDataBloc>();
                bloc.add(UpdateNodeFieldTyped(fieldKey: fieldKey, value: val));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class NodeCheckbox extends StatelessWidget {
  final String label;
  final String fieldKey;

  const NodeCheckbox({super.key, required this.label, required this.fieldKey});

  bool _checkedValue(NodeDataBloc bloc) {
    final currentText = bloc.node.data.formatField(fieldKey);
    return currentText == "true";
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NodeDataBloc>();
    final value = _checkedValue(bloc);
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label)),
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: value,
            onChanged: (val) {
              if (val == null) return;
              bloc.add(UpdateNodeFieldTyped(fieldKey: fieldKey, value: val));
            },
          ),
        ),
      ],
    );
  }
}

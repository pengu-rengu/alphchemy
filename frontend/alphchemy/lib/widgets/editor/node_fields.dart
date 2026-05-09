import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";

class NodeTextField extends StatelessWidget {
  final String label;
  final String fieldKey;

  const NodeTextField({super.key, required this.label, required this.fieldKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeDataState>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = bloc.nodeData.formatField(fieldKey);

        return Row(children: [
          SizedBox(width: 200, child: Text(label)),
          Expanded(child: SyncedTextField(
            text: value,
            onChanged: (val) {
              bloc.add(UpdateNodeField(fieldKey: fieldKey, text: val));
            }
          ))
        ]);
      }
    );
  }
}

class NodeDropdown<T> extends StatelessWidget {
  final String label;
  final String fieldKey;
  final List<T> options;
  final String Function(T) optionLabel;

  const NodeDropdown({
    super.key,
    required this.label,
    required this.fieldKey,
    required this.options,
    required this.optionLabel
  });

  T? _selectedValue(NodeDataBloc bloc) {
    final currentText = bloc.nodeData.formatField(fieldKey);
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
          SizedBox(width: 200, child: Text(label)),
          
          Expanded(child: DropdownButton<T>( // change to DropdownMenu
            key: ValueKey<String>("node_dropdown_$fieldKey"),
            value: value,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox(),
            items: options.map((opt) {
              return DropdownMenuItem<T>(
                value: opt,
                child: Text(optionLabel(opt))
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              bloc.add(UpdateNodeFieldTyped(fieldKey: fieldKey, value: val));
            }
          ))
        ]);
      }
    );
  }
}

// replace with true/false dropdown
class NodeCheckbox extends StatelessWidget {
  final String label;
  final String fieldKey;

  const NodeCheckbox({super.key, required this.label, required this.fieldKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeDataState>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = bloc.nodeData.formatField(fieldKey) == "true";

        return Row(children: [
          SizedBox(width: 200, child: Text(label)),
          SizedBox(
            height: 20,
            width: 20,
            child: Checkbox(
              key: ValueKey<String>("node_checkbox_$fieldKey"),
              value: value,
              onChanged: (val) {
                if (val == null) return;
                bloc.add(UpdateNodeFieldTyped(fieldKey: fieldKey, value: val));
              }
            )
          )
        ]);
      }
    );
  }
}

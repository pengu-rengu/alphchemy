import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class NodeTextField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const NodeTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label)
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: TextField(
              controller: TextEditingController(text: value),
              onChanged: onChanged
            )
          )
        )
      ]
    );
  }
}

class NodeDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  const NodeDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.labelFor,
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label)
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              underline: SizedBox(),
              items: options.map((opt) {
                return DropdownMenuItem<T>(
                  value: opt,
                  child: Text(labelFor(opt))
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                onChanged(val);
                context.read<NodeDataBloc>().add(const NodeDataChanged());
              }
            )
          )
        )
      ]
    );
  }
}

class NodeCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const NodeCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label)
        ),
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: value,
            onChanged: (val) {
              if (val == null) return;
              onChanged(val);
              context.read<NodeDataBloc>().add(const NodeDataChanged());
            }
          )
        )
      ]
    );
  }
}

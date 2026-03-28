import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/widgets/list_editor.dart";
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

class NodeListField<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final String Function(T) display;
  final T Function(String) parse;
  final T Function() defaultItem;
  final ValueChanged<List<T>> onChanged;

  const NodeListField({
    super.key,
    required this.label,
    required this.items,
    required this.display,
    required this.parse,
    required this.defaultItem,
    required this.onChanged
  });

  void _onListChanged(BuildContext context, List<dynamic> updated) {
    final parsed = updated.map((item) => parse(item as String));
    final result = parsed.toList();
    onChanged(result);
    if (result.length == items.length) return;
    final bloc = context.read<NodeDataBloc>();
    bloc.add(const NodeDataChanged());
    bloc.add(const NodeDataResize());
  }

  @override
  Widget build(BuildContext context) {
    final displayed = items.map(display);
    final itemsList = displayed.toList();
    final defaultVal = defaultItem();
    final defaultStr = display(defaultVal);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(label)
        ),
        Expanded(
          child: ListEditor(
            items: itemsList,
            createItem: () => defaultStr,
            onChanged: (updated) => _onListChanged(context, updated)
          )
        )
      ]
    );
  }
}

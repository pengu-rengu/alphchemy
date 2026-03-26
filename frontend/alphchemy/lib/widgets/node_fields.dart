import "package:flutter/material.dart";

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
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.white70)
          )
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: TextField(
              controller: TextEditingController(text: value),
              style: TextStyle(fontSize: 10, color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)
                )
              ),
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
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.white70)
          )
        ),
        Expanded(
          child: SizedBox(
            height: 24,
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: Colors.grey[800],
              style: TextStyle(fontSize: 10, color: Colors.white),
              underline: SizedBox(),
              items: options.map((opt) {
                return DropdownMenuItem<T>(
                  value: opt,
                  child: Text(labelFor(opt))
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
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
          child: Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.white70)
          )
        ),
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: value,
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap
          )
        )
      ]
    );
  }
}

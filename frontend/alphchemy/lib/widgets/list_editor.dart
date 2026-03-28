import "package:flutter/material.dart";

class ListEditor extends StatelessWidget {
  final List<dynamic> items;
  final ValueChanged<List<dynamic>> onChanged;
  final dynamic Function()? createItem;
  final bool nested;

  const ListEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.createItem,
    this.nested = false
  });

  void _addItem() {
    dynamic newItem;
    if (nested) {
      newItem = <dynamic>[];
    } else if (createItem != null) {
      newItem = createItem!();
    } else {
      newItem = "";
    }
    onChanged([...items, newItem]);
  }

  void _updateItem(int idx, dynamic value) {
    final updated = [...items];
    updated[idx] = value;
    onChanged(updated);
  }

  void _deleteItem(int idx) {
    final updated = [...items];
    updated.removeAt(idx);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(items.length, (i) {
          if (items[i] is List) {
            return NestedListRow(
              key: ValueKey("nested_${i}_${(items[i] as List).length}"),
              items: List<dynamic>.from(items[i] as List),
              onChanged: (val) => _updateItem(i, val),
              onDelete: () => _deleteItem(i)
            );
          }
          return ListItemRow(
            key: ValueKey("item_${i}_${items[i]}"),
            value: items[i].toString(),
            onChanged: (val) => _updateItem(i, val),
            onDelete: () => _deleteItem(i)
          );
        }),
        ListAddButton(onPressed: _addItem)
      ]
    );
  }
}

class ListItemRow extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  const ListItemRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onDelete
  });

  @override
  State<ListItemRow> createState() => _ListItemRowState();
}

class _ListItemRowState extends State<ListItemRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(ListItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    if (_controller.text == widget.value) return;
    final selection = TextSelection.collapsed(offset: widget.value.length);
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: selection
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged
            )
          ),
          SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              icon: Icon(Icons.close, size: 12),
              padding: EdgeInsets.zero,
              onPressed: widget.onDelete
            )
          )
        ]
      )
    );
  }
}

class NestedListRow extends StatelessWidget {
  final List<dynamic> items;
  final ValueChanged<List<dynamic>> onChanged;
  final VoidCallback onDelete;

  const NestedListRow({
    super.key,
    required this.items,
    required this.onChanged,
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Text(
                "[${items.length} items]",
                style: TextStyle(fontSize: 11, color: Colors.white54)
              ),
              Spacer(),
              SizedBox(
                width: 20,
                height: 20,
                child: IconButton(
                  icon: Icon(Icons.close, size: 12),
                  padding: EdgeInsets.zero,
                  onPressed: onDelete
                )
              )
            ]
          )
        ),
        Padding(
          padding: EdgeInsets.only(left: 12),
          child: ListEditor(
            items: items,
            onChanged: onChanged
          )
        )
      ]
    );
  }
}

class ListAddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ListAddButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 20,
        width: 20,
        child: IconButton(
          icon: Icon(Icons.add, size: 14),
          padding: EdgeInsets.zero,
          onPressed: onPressed
        )
      )
    );
  }
}

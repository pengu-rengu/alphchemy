import "package:alphchemy/model/generator/node_data.dart";

sealed class EditorTreeItem {
  const EditorTreeItem();

  String get rowKey;
  double get rowExtent;
}

class HeaderTreeItem extends EditorTreeItem {
  final NodeData nodeData;

  const HeaderTreeItem({required this.nodeData});

  @override
  String get rowKey {
    return "object_${nodeData.nodeId}";
  }

  @override
  double get rowExtent => 50.0;
}

class FieldsTreeItem extends EditorTreeItem {
  final NodeData nodeData;

  const FieldsTreeItem({required this.nodeData});

  @override
  String get rowKey {
    return "fields_${nodeData.nodeId}";
  }

  @override
  double get rowExtent => 25.0 + nodeData.fieldCount * 25.0;
}

class SlotTreeItem extends EditorTreeItem {
  final NodeData parent;
  final ChildSlot slot;

  const SlotTreeItem({
    required this.parent,
    required this.slot
  });

  @override
  String get rowKey {
    return "slot_${parent.nodeId}_${slot.key}";
  }

  @override
  double get rowExtent => 40.0;
}

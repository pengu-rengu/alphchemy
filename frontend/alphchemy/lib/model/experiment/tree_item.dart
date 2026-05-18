import "package:alphchemy/model/experiment/node_data.dart";

sealed class TreeItem {
  const TreeItem();

  String get rowKey;
  double get rowExtent;
}

class HeaderTreeItem extends TreeItem {
  final NodeData nodeData;

  const HeaderTreeItem({required this.nodeData});

  @override
  String get rowKey {
    return "object_${nodeData.nodeId}";
  }

  @override
  double get rowExtent => 50.0;
}

class FieldsTreeItem extends TreeItem {
  final NodeData nodeData;

  const FieldsTreeItem({required this.nodeData});

  @override
  String get rowKey {
    return "fields_${nodeData.nodeId}";
  }

  @override
  double get rowExtent => 50.0 + nodeData.fields.length * 25.0;
}

class SlotTreeItem extends TreeItem {
  final NodeData parent;
  final ChildSlot slot;

  const SlotTreeItem({required this.parent, required this.slot});

  @override
  String get rowKey {
    return "slot_${parent.nodeId}_${slot.field}";
  }

  @override
  double get rowExtent => 50.0;
}

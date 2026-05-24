import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/experiment/tree_item.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/experiment_tree.dart";
import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class EditorEvent {
  const EditorEvent();
}

class AddTreeChild extends EditorEvent {
  final String parentId;
  final String field;
  final NodeType nodeType;

  const AddTreeChild({
    required this.parentId,
    required this.field,
    required this.nodeType
  });
}

class DeleteTreeChild extends EditorEvent {
  final String nodeId;

  const DeleteTreeChild({required this.nodeId});
}

class UpdateTreeNodeData extends EditorEvent {
  final NodeData nodeData;

  const UpdateTreeNodeData({required this.nodeData});
}

class EditorState {
  final Experiment experiment;
  final List<TreeSliverNode<TreeItem>> tree;
  final int treeVersion;
  final String? errorMessage;

  const EditorState({required this.experiment, required this.tree, this.treeVersion = 0, this.errorMessage});
}

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({Experiment? experiment}) : super(_init(experiment)) {
    on<AddTreeChild>(_onAddChild);
    on<DeleteTreeChild>(_onDeleteChild);
    on<UpdateTreeNodeData>(_onUpdateNodeData);
  }

  static EditorState _init(Experiment? experiment) {
    final root = experiment ?? Experiment();
    final tree = <TreeSliverNode<TreeItem>>[createTreeNode(root, {})];
    return EditorState(experiment: root, tree: tree);
  }

  void _onAddChild(AddTreeChild event, Emitter<EditorState> emit) {
    try {
      final newExperiment = state.experiment.copy();
      final parent = newExperiment.find(event.parentId);
      if (parent == null) {
        _emitError(emit: emit, error: "parent ${event.parentId} not found");
        return;
      }
      parent.addChild(event.field, event.nodeType.emptyNode());

      final expandedKeys = collectExpandedKeys(state.tree);
      expandedKeys.add("slot_${event.parentId}_${event.field}");
      final newTree = <TreeSliverNode<TreeItem>>[createTreeNode(newExperiment, expandedKeys)];
      emit(EditorState(
        experiment: newExperiment,
        tree: newTree,
        treeVersion: state.treeVersion + 1
      ));
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onDeleteChild(DeleteTreeChild event, Emitter<EditorState> emit) {
    try {
      final newExperiment = state.experiment.copy();
      if (event.nodeId == newExperiment.nodeId) {
        _emitError(emit: emit, error: "cannot remove root node");
        return;
      }
      if (!newExperiment.removeChild(event.nodeId)) {
        _emitError(emit: emit, error: "node ${event.nodeId} not found");
        return;
      }

      final expandedKeys = collectExpandedKeys(state.tree);
      final newTree = <TreeSliverNode<TreeItem>>[createTreeNode(newExperiment, expandedKeys)];
      emit(EditorState(
        experiment: newExperiment,
        tree: newTree,
        treeVersion: state.treeVersion + 1
      ));
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _onUpdateNodeData(UpdateTreeNodeData event, Emitter<EditorState> emit) {
    try {
      final newExperiment = state.experiment.copy();
      final updatedNode = event.nodeData;

      if (updatedNode.nodeId == newExperiment.nodeId) {
        newExperiment.updateFieldsFrom(updatedNode);
        emit(EditorState(
          experiment: newExperiment,
          tree: [...state.tree],
          treeVersion: state.treeVersion + 1
        ));
        return;
      }

      final currentNode = newExperiment.find(updatedNode.nodeId);
      if (currentNode == null) {
        _emitError(emit: emit, error: "node ${updatedNode.nodeId} not found");
        return;
      }

      currentNode.updateFieldsFrom(updatedNode);
      emit(EditorState(
        experiment: newExperiment,
        tree: [...state.tree],
        treeVersion: state.treeVersion
      ));
    } catch (error) {
      _emitError(emit: emit, error: error);
    }
  }

  void _emitError({required Emitter<EditorState> emit, required Object error}) {
    final newState = EditorState(
      experiment: state.experiment.copy(),
      tree: [...state.tree],
      errorMessage: error.toString()
    );
    emit(newState);
  }
}

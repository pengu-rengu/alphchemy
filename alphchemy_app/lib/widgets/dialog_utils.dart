import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:forui/forui.dart";

Future<T?> showDialogUtil<T>({required BuildContext context, required String title, required Widget content, required List<Widget> Function(BuildContext) actions}) async {
  return await showFDialog<T>(
    context: context,
    builder: (innerContext, style, animation) => FDialog(
      title: LargeText(title),
      body: content,
      actions: actions(innerContext)
    )
  );
}

Future<void> errorDialog({required BuildContext context, required String message}) async {
  await showDialogUtil<void>(
    context: context,
    title: "Error",
    content: NormalText(message),
    actions: (innerContext) => [FButton(
      onPress: () => Navigator.pop(innerContext),
      child: const InvertedText("Close")
    )]
  );
}

Future<bool> confirmDeleteDialog({required BuildContext context, required String title}) async {
  return await showDialogUtil<bool>(
    context: context,
    title: "Confirm Deletion",
    content: NormalText("Delete \"$title\"?"),
    actions: (innerContext) => [
      FButton(
        variant: FButtonVariant.outline,
        onPress: () => Navigator.pop(context, false),
        child: const NormalText("Cancel")
      ),
      FButton(
        variant: FButtonVariant.destructive,
        onPress: () => Navigator.pop(context, true),
        child: const NormalText("Delete")
      )
    ]
  ) ?? false;
}

Future<String?> renameDialog({required BuildContext context, required String title}) async {
  final controller = TextEditingController(text: title);

  return await showDialogUtil<String>(
    context: context,
    title: "Rename",
    content: StyledTextField(
      controller: controller,
      autofocus: true
    ),
    actions: (innerContext) => [
      FButton(
        variant: FButtonVariant.outline,
        onPress: () => Navigator.pop(innerContext),
        child: const NormalText("Cancel")
      ),
      FButton(
        onPress: () => Navigator.pop(innerContext, controller.text),
        child: const InvertedText("Rename")
      )
    ]
  );
}

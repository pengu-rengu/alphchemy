import "package:alphchemy/blocs/theme_bloc.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

Future<T?> showDialogUtil<T>({required BuildContext context, required String title, required Widget content, required List<Widget> Function(BuildContext) actions}) async {
  return await showDialog<T>(
    context: context, 
    builder: (innerContext) => AlertDialog(
      title: LargeText(title),
      content: content,
      actions: actions(innerContext),
    )
  );
}

Future<void> errorDialog({required BuildContext context, required String message}) async {
  await showDialogUtil<void>(
    context: context,
    title: "Error",
    content: NormalText(message),
    actions: (innerContext) => [FilledButton(
      onPressed: () {
        Navigator.pop(innerContext);
      }, 
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
      FilledButton(
        onPressed: () {
          Navigator.pop(context, false);
        }, 
        child: const InvertedText("Cancel")
      ),
      FilledButton(
        style: Theme.of(context).filledButtonTheme.style!.copyWith(
          overlayColor: WidgetStatePropertyAll(Colors.red.shade800),
          backgroundColor: WidgetStatePropertyAll(Colors.red.shade900)
        ),
        onPressed: () {
          Navigator.pop(context, true);
        }, 
        child: context.read<ThemeBloc>().state == ThemeMode.dark ? const NormalText("Delete") : const InvertedText("Delete")
      )
      
    ]
  ) ?? false;
}

Future<String?> renameDialog({required BuildContext context, required String title}) async {
  final controller = TextEditingController(text: title);

  return await showDialogUtil<String>(
    context: context, 
    title: "Rename",
    content: TextField(
      controller: controller,
      autofocus: true
    ), 
    actions: (innerContext) => [
      FilledButton(
        onPressed: () => Navigator.pop(innerContext), 
        child: const NormalText("Cancel")
      ),
      FilledButton(
        onPressed: () => Navigator.pop(innerContext, controller.text), 
        child: const NormalText("Rename")
      )
    ]
  );
}


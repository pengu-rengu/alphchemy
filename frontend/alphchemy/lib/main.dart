import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/objects/mock_data.dart";
import "package:alphchemy/pages/home.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

final theme = ThemeData(
  brightness: Brightness.dark,

  textTheme: TextTheme(

    bodyMedium: TextStyle(fontSize: 12, color: Colors.white70)
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 4
    ),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white30)
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white30)
    )
  ),
  checkboxTheme: CheckboxThemeData(
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap
  )
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final editorBloc = EditorBloc();
  editorBloc.add(LoadGraphFromJson(json: mockWrapperJson));

  runApp(MaterialApp(
    theme: theme,
    home: BlocProvider.value(value: editorBloc, child: HomePage())
  ));
}

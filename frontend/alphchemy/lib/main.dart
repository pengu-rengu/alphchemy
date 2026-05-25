import "package:alphchemy/blocs/theme_bloc.dart";
import "package:alphchemy/env.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;
import "package:supabase_flutter/supabase_flutter.dart";

const light1 = Color.fromRGBO(200, 200, 200, 1.0);
const light2 = Color.fromRGBO(190, 190, 190, 1.0);
const light3 = Color.fromRGBO(160, 160, 160, 1.0);
const dark1 = Color.fromRGBO(40, 40, 40, 1.0);
const dark2 = Color.fromRGBO(30, 30, 30, 1.0);
const dark3 = Color.fromRGBO(70, 70, 70, 1.0);

class AppColors extends ThemeExtension<AppColors> {
  final Color bgColor1;
  final Color bgColor2;
  final Color bgColor3;
  final Color fgColor1;
  final Color fgColor2;

  const AppColors({
    required this.bgColor1,
    required this.bgColor2,
    required this.bgColor3,
    required this.fgColor1,
    required this.fgColor2
  });

  @override
  AppColors copyWith({Color? bgColor1, Color? bgColor2, Color? bgColor3, Color? fgColor1, Color? fgColor2}) {
    return AppColors(
      bgColor1: bgColor1 ?? this.bgColor1,
      bgColor2: bgColor2 ?? this.bgColor2,
      bgColor3: bgColor3 ?? this.bgColor3,
      fgColor1: fgColor1 ?? this.fgColor1,
      fgColor2: fgColor2 ?? this.fgColor2
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double progress) {
    return this;
  }
}

ThemeData buildTheme({required Brightness brightness, required Color bgColor1, required Color bgColor2, required Color bgColor3, required Color fgColor1, required Color fgColor2}) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: bgColor1,
      brightness: brightness
    ),
    splashFactory: NoSplash.splashFactory,
    hoverColor: fgColor1.withAlpha(10),
    scaffoldBackgroundColor: bgColor1,
    extensions: [AppColors(bgColor1: bgColor1, bgColor2: bgColor2, bgColor3: bgColor3, fgColor1: fgColor1, fgColor2: fgColor2)
    ],
    dialogTheme: DialogThemeData(
      backgroundColor: bgColor1,
      shape: const Border()
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: bgColor2,
      indicatorColor: bgColor3,
      indicatorShape: const Border()
    ),
    dividerTheme: DividerThemeData(
      color: bgColor3
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 20, color: fgColor1),
      displayMedium: TextStyle(fontSize: 12, color: fgColor1),
      labelMedium: TextStyle(fontSize: 12, color: bgColor1),
      titleMedium: TextStyle(fontSize: 12, color: fgColor1, fontWeight: FontWeight.bold)
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: bgColor3,
      selectionColor: bgColor3
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.all(2),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: fgColor2),
        borderRadius: BorderRadius.zero
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: fgColor2),
        borderRadius: BorderRadius.zero
      )
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        backgroundColor: WidgetStateProperty.fromMap({
          WidgetState.selected: fgColor1,
          WidgetState.disabled: bgColor1
        })
      )
    ),
    checkboxTheme: const CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(visualDensity: VisualDensity.compact)
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      expansionAnimationStyle: AnimationStyle.noAnimation,
      expandedAlignment: AlignmentGeometry.centerLeft,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      iconColor: fgColor1
    ),
    cardTheme: CardThemeData(
      color: bgColor2,
      shape: Border.all(color: bgColor3)
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        overlayColor: WidgetStatePropertyAll(fgColor2),
        backgroundColor: WidgetStatePropertyAll(fgColor1)
      )
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(fontSize: 12, color: fgColor1),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: fgColor2),
          borderRadius: BorderRadius.zero
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: fgColor2),
          borderRadius: BorderRadius.zero
        )
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(bgColor1),
        visualDensity: VisualDensity.compact
      )
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bgColor2,
      selectedColor: fgColor1,
      disabledColor: bgColor2,
      side: BorderSide(color: bgColor3),
      shape: const RoundedRectangleBorder(),
      showCheckmark: false
    ),
    listTileTheme: ListTileThemeData(
      selectedTileColor: fgColor1.withAlpha(50)
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: bgColor3
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: bgColor1
    )
  );
}

final darkTheme = buildTheme(
  brightness: Brightness.dark,
  bgColor1: dark1,
  bgColor2: dark2,
  bgColor3: dark3,
  fgColor1: light1,
  fgColor2: light3
);

final lightTheme = buildTheme(
  brightness: Brightness.light,
  bgColor1: light1,
  bgColor2: light2,
  bgColor3: light3,
  fgColor1: dark1,
  fgColor2: dark3
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey
  );

  final supabaseClient = Supabase.instance.client;
  final docsHttpClient = http.Client();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SupabaseClient>.value(value: supabaseClient),
        RepositoryProvider<http.Client>.value(value: docsHttpClient)
      ],
      child: BlocProvider<ThemeBloc>(
        create: (_) => ThemeBloc(),
        child: BlocBuilder<ThemeBloc, ThemeMode>(
          builder: (context, mode) => MaterialApp(
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: mode,
            home: const ExperimentsPage()
          )
        )
      )
    )
  );
}

import "package:alphchemy/blocs/theme_bloc.dart";
import "package:alphchemy/env.dart";
import "package:alphchemy/pages/experiments_page.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";
import "package:http/http.dart" as http;
import "package:supabase_flutter/supabase_flutter.dart";

final lightTheme = FThemes.neutral.light.desktop;
final darkTheme = FThemes.neutral.dark.desktop;
final lightMaterialTheme = lightTheme.toApproximateMaterialTheme();
final darkMaterialTheme = darkTheme.toApproximateMaterialTheme();

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
          builder: (context, mode) {
            final isDark = mode == ThemeMode.dark;
            final theme = isDark ? darkTheme : lightTheme;
            return MaterialApp(
              theme: lightMaterialTheme,
              darkTheme: darkMaterialTheme,
              themeMode: mode,
              builder: (context, child) => FTheme(data: theme, child: child!),
              home: const ExperimentsPage()
            );
          }
        )
      )
    )
  );
}

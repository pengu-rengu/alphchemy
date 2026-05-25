import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

sealed class ThemeEvent {
  const ThemeEvent();
}

class ToggleTheme extends ThemeEvent {
  const ToggleTheme();
}


class ThemeBloc extends Bloc<ThemeEvent, ThemeMode> {
  ThemeBloc() : super(ThemeMode.dark) {
    on<ToggleTheme>(_onToggle);
  }

  void _onToggle(ToggleTheme event, Emitter<ThemeMode> emit) {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

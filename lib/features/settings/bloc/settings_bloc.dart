import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/bloc/trip_bloc.dart';
import '../../home/bloc/trip_event.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final TripBloc tripBloc;

  SettingsBloc({required this.tripBloc})
      : super(const SettingsState.initial()) {
    on<ToggleAutoRecord>(_onToggleAutoRecord);
    on<ToggleDarkMode>(_onToggleDarkMode);
    on<DeleteAllData>(_onDeleteAllData);
    on<LoadSettings>(_onLoadSettings);

    // Load settings when bloc is created
    add(const LoadSettings());
  }

  void _onToggleAutoRecord(
    ToggleAutoRecord event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isAutoRecordEnabled: event.isEnabled));
    await _saveAutoRecordSetting(event.isEnabled);
  }

  void _onToggleDarkMode(
    ToggleDarkMode event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isDarkModeEnabled: event.isEnabled));
    await _saveDarkModeSetting(event.isEnabled);
  }

  void _onDeleteAllData(
    DeleteAllData event,
    Emitter<SettingsState> emit,
  ) {
    tripBloc.add(const ClearAllTrips());
  }

  void _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkModeEnabled = prefs.getBool('isDarkModeEnabled') ?? false;
    final isAutoRecordEnabled = prefs.getBool('isAutoRecordEnabled') ?? false;

    emit(SettingsState(
      isDarkModeEnabled: isDarkModeEnabled,
      isAutoRecordEnabled: isAutoRecordEnabled,
    ));
  }

  Future<void> _saveDarkModeSetting(bool isDarkModeEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkModeEnabled', isDarkModeEnabled);
  }

  Future<void> _saveAutoRecordSetting(bool isAutoRecordEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAutoRecordEnabled', isAutoRecordEnabled);
  }
}

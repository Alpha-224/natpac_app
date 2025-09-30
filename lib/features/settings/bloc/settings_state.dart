import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final bool isAutoRecordEnabled;
  final bool isDarkModeEnabled;

  const SettingsState({
    required this.isAutoRecordEnabled,
    required this.isDarkModeEnabled,
  });

  // Initial state with both settings disabled
  const SettingsState.initial()
      : isAutoRecordEnabled = false,
        isDarkModeEnabled = false;

  // Copy with method for easy state updates
  SettingsState copyWith({
    bool? isAutoRecordEnabled,
    bool? isDarkModeEnabled,
  }) {
    return SettingsState(
      isAutoRecordEnabled: isAutoRecordEnabled ?? this.isAutoRecordEnabled,
      isDarkModeEnabled: isDarkModeEnabled ?? this.isDarkModeEnabled,
    );
  }

  @override
  List<Object> get props => [isAutoRecordEnabled, isDarkModeEnabled];
}

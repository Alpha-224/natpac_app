import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object> get props => [];
}

class ToggleAutoRecord extends SettingsEvent {
  final bool isEnabled;

  const ToggleAutoRecord({required this.isEnabled});

  @override
  List<Object> get props => [isEnabled];
}

class ToggleDarkMode extends SettingsEvent {
  final bool isEnabled;

  const ToggleDarkMode({required this.isEnabled});

  @override
  List<Object> get props => [isEnabled];
}

class DeleteAllData extends SettingsEvent {
  const DeleteAllData();
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

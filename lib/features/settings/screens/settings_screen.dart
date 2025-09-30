import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../../authentication/bloc/auth_bloc.dart';
import '../../authentication/bloc/auth_event.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Trip Data'),
          content: const Text(
            'Are you sure you want to delete all trip data? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (context.mounted) {
        context.read<SettingsBloc>().add(const DeleteAllData());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All trip data has been deleted'),
          ),
        );
      }
    }
  }

  Future<void> _showSignOutConfirmationDialog(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (context.mounted) {
        context.read<AuthBloc>().add(const SignOutRequested());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Account Section
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: const Text('Account'),
                      subtitle: Text(user?.email ?? 'No email'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trip Recording Settings
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Trip Recording',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Enable Auto-Trip Recording'),
                      subtitle: const Text(
                        'Automatically detect and record trips in the background',
                      ),
                      value: state.isAutoRecordEnabled,
                      onChanged: (bool value) {
                        context.read<SettingsBloc>().add(
                              ToggleAutoRecord(isEnabled: value),
                            );
                      },
                      secondary: const Icon(Icons.auto_mode),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Appearance Settings
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Appearance',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Enable dark theme'),
                      value: state.isDarkModeEnabled,
                      onChanged: (bool value) {
                        context.read<SettingsBloc>().add(
                              ToggleDarkMode(isEnabled: value),
                            );
                      },
                      secondary: Icon(
                        state.isDarkModeEnabled
                            ? Icons.dark_mode
                            : Icons.light_mode,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Data Management
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Data Management',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Delete All Trip Data'),
                      subtitle:
                          const Text('Permanently delete all recorded trips'),
                      onTap: () => _showDeleteConfirmationDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Account Actions
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign Out'),
                      subtitle: const Text('Sign out of your account'),
                      onTap: () => _showSignOutConfirmationDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // App Info
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About'),
                      subtitle: const Text('NATPAC Trip Tracker v1.0.0'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

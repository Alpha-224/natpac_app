import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

// Fixed imports
import 'firebase_options.dart';
import 'features/authentication/bloc/auth_bloc.dart';
import 'features/home/bloc/trip_bloc.dart';
import 'features/settings/bloc/settings_bloc.dart';
import 'data/trip_repository.dart'; // Add this import
import 'auth_gate.dart';

// Professional services
import 'services/storage_service.dart';
import 'services/location_service_new.dart';
import 'services/activity_recognition_service_new.dart';
import 'services/clustering_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize TripRepository with Hive
  final tripRepository = TripRepository();
  await tripRepository.initialize(); // ADD THIS LINE

  // ADD THIS LINE TO CLEAR CORRUPTED DATA:
  await tripRepository.clearAllData();

  // Initialize professional services
  try {
    await StorageService.instance.initialize();
    ClusteringService.instance.loadClustersFromStorage();
  } catch (e) {
    debugPrint('Error initializing professional services: $e');
  }

  runApp(NatpacTripTracker(tripRepository: tripRepository)); // Pass repository
}

class NatpacTripTracker extends StatelessWidget {
  final TripRepository tripRepository;

  const NatpacTripTracker({super.key, required this.tripRepository});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc()),
        BlocProvider<TripBloc>(
          create: (context) => TripBloc(tripRepository: tripRepository),
        ),
        BlocProvider<SettingsBloc>(
          create: (context) => SettingsBloc(
            tripBloc: BlocProvider.of<TripBloc>(context),
          ),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => LocationService.instance),
        ChangeNotifierProvider(
            create: (_) => ActivityRecognitionService.instance),
        ChangeNotifierProvider(create: (_) => ClusteringService.instance),
        Provider<TripRepository>(create: (_) => tripRepository),
      ],
      child: MaterialApp(
        title: 'NATPAC Trip Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          primaryColor: Colors.deepPurple,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}





//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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../../../data/models.dart';
import '../bloc/trip_bloc.dart';
import '../bloc/trip_event.dart';
import '../bloc/trip_state.dart';
import '../../trip_planning/screens/trip_planner_screen.dart';
import '../../trip_planning/screens/edit_planned_trip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    context.read<TripBloc>().add(const LoadTrips());

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning!';
    } else if (hour < 17) {
      return 'Good Afternoon!';
    } else {
      return 'Good Evening!';
    }
  }

  Map<String, dynamic> _calculateTodayStats(List<Trip> trips) {
    final today = DateTime.now();
    final todayTrips = trips.where((trip) {
      return trip.timestamp.day == today.day &&
          trip.timestamp.month == today.month &&
          trip.timestamp.year == today.year;
    }).toList();

    double totalDistance = 0;
    Duration totalDuration = Duration.zero;
    Map<TransportMode, int> transportCount = {};
    Map<TransportMode, double> transportDistance = {};

    for (final trip in todayTrips) {
      totalDistance += trip.distanceInKm;
      totalDuration += trip.duration;

      transportCount[trip.transportMode] =
          (transportCount[trip.transportMode] ?? 0) + 1;
      transportDistance[trip.transportMode] =
          (transportDistance[trip.transportMode] ?? 0) + trip.distanceInKm;
    }

    return {
      'tripCount': todayTrips.length,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'transportCount': transportCount,
      'transportDistance': transportDistance,
      'trips': todayTrips,
    };
  }

  Map<String, dynamic> _calculateWeeklyStats(List<Trip> trips) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekTrips = trips.where((trip) {
      return trip.timestamp.isAfter(weekStart) &&
          trip.timestamp.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    double totalDistance = 0;
    Duration totalDuration = Duration.zero;

    for (final trip in weekTrips) {
      totalDistance += trip.distanceInKm;
      totalDuration += trip.duration;
    }

    return {
      'tripCount': weekTrips.length,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
    };
  }

  List<Trip> _getFrequentTrips(List<Trip> trips) {
    final Map<String, List<Trip>> routeGroups = {};

    for (final trip in trips) {
      final routeKey =
          '${_simplifyLocation(trip.originName)}-${_simplifyLocation(trip.destinationName)}';
      routeGroups[routeKey] = (routeGroups[routeKey] ?? [])..add(trip);
    }

    final frequentRoutes = routeGroups.entries
        .where((entry) => entry.value.length >= 2)
        .toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return frequentRoutes.take(3).map((entry) => entry.value.first).toList();
  }

  // FIXED: Get actual planned trips from BLoC state, no sample data
  List<PlannedTrip> _getUpcomingPlannedTrips(TripState state) {
    if (state is TripLoaded) {
      final now = DateTime.now();
      // Filter for upcoming trips only and sort by date
      final upcoming = state.plannedTrips
          .where((trip) => trip.plannedDateTime.isAfter(now))
          .toList()
        ..sort((a, b) => a.plannedDateTime.compareTo(b.plannedDateTime));
      return upcoming.take(5).toList(); // Show up to 5 upcoming trips
    }
    return [];
  }

  String _simplifyLocation(String location) {
    final parts = location.split(',');
    return parts.isEmpty ? location : parts[0].trim();
  }

  List<_ChartData> _prepareTransportChartData(
      Map<TransportMode, double> transportDistance) {
    return transportDistance.entries
        .where((entry) => entry.value > 0)
        .map((entry) => _ChartData(
              _getTransportModeLabel(entry.key),
              entry.value,
              _getTransportModeColor(entry.key),
            ))
        .toList();
  }

  List<_WeeklyData> _prepareWeeklyChartData(List<Trip> trips) {
    final now = DateTime.now();
    final List<_WeeklyData> weekData = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayTrips = trips.where((trip) {
        return trip.timestamp.day == date.day &&
            trip.timestamp.month == date.month &&
            trip.timestamp.year == date.year;
      }).toList();

      double dayDistance =
          dayTrips.fold(0, (sum, trip) => sum + trip.distanceInKm);

      weekData.add(_WeeklyData(
        DateFormat('EEE').format(date),
        dayDistance,
      ));
    }

    return weekData;
  }

  String _getTransportModeLabel(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return 'Car';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.walking:
        return 'Walking';
      case TransportMode.cycling:
        return 'Cycling';
      case TransportMode.train:
        return 'Train';
      case TransportMode.still:
        return 'Still';
    }
  }

  Color _getTransportModeColor(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return Colors.blue;
      case TransportMode.bus:
        return Colors.green;
      case TransportMode.walking:
        return Colors.orange;
      case TransportMode.cycling:
        return Colors.purple;
      case TransportMode.train:
        return Colors.red;
      case TransportMode.still:
        return Colors.grey;
    }
  }

  IconData _getTransportModeIcon(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return Icons.directions_car;
      case TransportMode.bus:
        return Icons.directions_bus;
      case TransportMode.walking:
        return Icons.directions_walk;
      case TransportMode.cycling:
        return Icons.directions_bike;
      case TransportMode.train:
        return Icons.train;
      case TransportMode.still:
        return Icons.location_disabled;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _getTimeUntilTrip(DateTime plannedDateTime) {
    final now = DateTime.now();
    final difference = plannedDateTime.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'starting now';
    }
  }

  String _getPlannedTripTitle(PlannedTrip trip) {
    final origin = _simplifyLocation(trip.originName);
    final destination = _simplifyLocation(trip.destinationName);

    if (destination.toLowerCase().contains('office') ||
        destination.toLowerCase().contains('tech') ||
        destination.toLowerCase().contains('work')) {
      return 'Work Commute';
    } else if (destination.toLowerCase().contains('mall') ||
        destination.toLowerCase().contains('shop')) {
      return 'Shopping Trip';
    } else if (destination.toLowerCase().contains('airport')) {
      return 'Airport Transfer';
    } else if (destination.toLowerCase().contains('station')) {
      return 'Railway Station';
    } else if (trip.transportMode == TransportMode.walking) {
      return 'Walking Trip';
    } else {
      return 'Trip to $destination';
    }
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedTripsSection(List<PlannedTrip> plannedTrips) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Upcoming Trips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    // Navigate and refresh when coming back
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<TripBloc>(),
                          child: const TripPlannerScreen(),
                        ),
                      ),
                    );
                    // Reload trips if a trip was added
                    if (result == true && mounted) {
                      context.read<TripBloc>().add(const LoadTrips());
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Plan Trip'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (plannedTrips.isEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Upcoming Trips',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Plan your next journey to see it here',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<TripBloc>(),
                              child: const TripPlannerScreen(),
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          context.read<TripBloc>().add(const LoadTrips());
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Plan Your First Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...plannedTrips.map((trip) => _buildPlannedTripCard(trip)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedTripCard(PlannedTrip trip) {
    final timeUntil = _getTimeUntilTrip(trip.plannedDateTime);
    final isUpcoming = trip.plannedDateTime.isAfter(DateTime.now());
    final tripTitle = _getPlannedTripTitle(trip);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUpcoming
              ? _getTransportModeColor(trip.transportMode)
                  .withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
        color: isUpcoming
            ? _getTransportModeColor(trip.transportMode).withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<TripBloc>(),
                child: EditPlannedTripScreen(plannedTrip: trip),
              ),
            ),
          );
          if (result == true && mounted) {
            context.read<TripBloc>().add(const LoadTrips());
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTransportModeColor(trip.transportMode)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTransportModeIcon(trip.transportMode),
                      color: _getTransportModeColor(trip.transportMode),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tripTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_simplifyLocation(trip.originName)} → ${_simplifyLocation(trip.destinationName)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeUntil,
                      style: TextStyle(
                        color:
                            isUpcoming ? Colors.green[700] : Colors.orange[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, HH:mm').format(trip.plannedDateTime),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.directions, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _getTransportModeLabel(trip.transportMode),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportChart(Map<TransportMode, double> transportDistance) {
    if (transportDistance.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(20),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No transport data today',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    final chartData = _prepareTransportChartData(transportDistance);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Transport Modes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCircularChart(
                series: <CircularSeries>[
                  DoughnutSeries<_ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (_ChartData data, _) => data.mode,
                    yValueMapper: (_ChartData data, _) => data.distance,
                    pointColorMapper: (_ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                    ),
                    enableTooltip: true,
                  ),
                ],
                tooltipBehavior: TooltipBehavior(enable: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(List<Trip> trips) {
    final weeklyData = _prepareWeeklyChartData(trips);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: const NumericAxis(
                  title: AxisTitle(text: 'Distance (km)'),
                ),
                series: <CartesianSeries>[
                  ColumnSeries<_WeeklyData, String>(
                    dataSource: weeklyData,
                    xValueMapper: (_WeeklyData data, _) => data.day,
                    yValueMapper: (_WeeklyData data, _) => data.distance,
                    color: Colors.deepPurple,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                tooltipBehavior: TooltipBehavior(enable: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequentTrips(List<Trip> frequentTrips) {
    if (frequentTrips.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.route, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text(
                'No Frequent Routes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Take more trips to see your frequent routes here',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequent Routes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...frequentTrips.map((trip) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getTransportModeColor(trip.transportMode)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getTransportModeIcon(trip.transportMode),
                          color: _getTransportModeColor(trip.transportMode),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_simplifyLocation(trip.originName)} → ${_simplifyLocation(trip.destinationName)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${trip.distanceInKm.toStringAsFixed(1)} km • ${_formatDuration(trip.duration)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NATPAC Trip Tracker'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<TripBloc, TripState>(
        builder: (context, state) {
          if (state is TripLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TripError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<TripBloc>().add(const LoadTrips());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final trips = (state is TripLoaded) ? state.allTrips : <Trip>[];
          final todayStats = _calculateTodayStats(trips);
          final weeklyStats = _calculateWeeklyStats(trips);
          final frequentTrips = _getFrequentTrips(trips);
          final plannedTrips = _getUpcomingPlannedTrips(state);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TripBloc>().add(const LoadTrips());
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      _getGreeting(),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                    ),
                    Text(
                      'Here\'s your travel summary',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Planned Trips Section
                    _buildPlannedTripsSection(plannedTrips),
                    const SizedBox(height: 24),

                    // Today's Stats
                    Column(
                      children: [
                        Row(
                          children: [
                            _buildStatCard(
                              'Today\'s Trips',
                              '${todayStats['tripCount']}',
                              'trips completed',
                              Icons.route,
                              Colors.blue,
                            ),
                            _buildStatCard(
                              'Distance',
                              '${todayStats['totalDistance'].toStringAsFixed(1)}',
                              'km traveled',
                              Icons.straighten,
                              Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStatCard(
                              'Travel Time',
                              _formatDuration(todayStats['totalDuration']),
                              'time on road',
                              Icons.access_time,
                              Colors.orange,
                            ),
                            _buildStatCard(
                              'This Week',
                              '${weeklyStats['tripCount']}',
                              'total trips',
                              Icons.calendar_today,
                              Colors.purple,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Charts Section
                    _buildTransportChart(todayStats['transportDistance']),
                    const SizedBox(height: 16),
                    _buildWeeklyChart(trips),
                    const SizedBox(height: 16),
                    _buildFrequentTrips(frequentTrips),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChartData {
  final String mode;
  final double distance;
  final Color color;

  _ChartData(this.mode, this.distance, this.color);
}

class _WeeklyData {
  final String day;
  final double distance;

  _WeeklyData(this.day, this.distance);
}

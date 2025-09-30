import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../data/models.dart'; // CORRECT PATH: 4 levels up from advanced/

class AnalyticsScreen extends StatefulWidget {
  final Trip trip; // BACK to Trip object!

  const AnalyticsScreen({
    super.key,
    required this.trip,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final Map<String, int> _transportModeDistribution = {};

  double _maxSpeed = 0;
  double _averageSpeed = 0;
  double _totalDistance = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  void _loadAnalyticsData() {
// Use REAL trip data where available, mock data as fallback
    setState(() {
      _totalDistance = widget.trip.distanceInKm * 1000; // Convert km to meters
      _maxSpeed = 28.5; // Mock data - would come from route analysis
      _averageSpeed =
          _totalDistance / widget.trip.duration.inSeconds; // Real calculation!

// Mock transport mode data - would be calculated from route analysis
      final mode = widget.trip.transportMode.name.toUpperCase();
      _transportModeDistribution[mode] = 100;
    });
  }

  List<FlSpot> _getSpeedData() {
// Mock speed data - in real app would come from GPS points
    return [
      const FlSpot(0, 0),
      const FlSpot(5, 15),
      const FlSpot(10, 25),
      const FlSpot(15, 20),
      const FlSpot(20, 28),
      const FlSpot(25, 22),
      const FlSpot(30, 0),
    ];
  }

  List<FlSpot> _getAltitudeData() {
// Mock altitude data - in real app would come from GPS points
    return [
      const FlSpot(0, 100),
      const FlSpot(5, 120),
      const FlSpot(10, 150),
      const FlSpot(15, 180),
      const FlSpot(20, 160),
      const FlSpot(25, 140),
      const FlSpot(30, 110),
    ];
  }

  List<PieChartSectionData> _getTransportModePieData() {
    if (_transportModeDistribution.isEmpty) return [];

    final total =
        _transportModeDistribution.values.fold(0, (sum, count) => sum + count);
    final colors = {
      'DRIVING': Colors.blue,
      'WALKING': Colors.orange,
      'CYCLING': Colors.green,
      'BUS': Colors.green,
      'TRAIN': Colors.red,
      'STILL': Colors.grey,
    };

    return _transportModeDistribution.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      return PieChartSectionData(
        color: colors[entry.key] ?? Colors.purple,
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Analytics'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
// Real Trip Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.route, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.trip.originName} → ${widget.trip.destinationName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            color: Colors.grey, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.trip.timestamp.day}/${widget.trip.timestamp.month}/${widget.trip.timestamp.year}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

// Summary stats (REAL DATA!)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip Summary',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Distance',
                          value:
                              '${widget.trip.distanceInKm.toStringAsFixed(2)} km', // REAL DATA
                          icon: Icons.straighten,
                        ),
                        _StatItem(
                          label: 'Duration',
                          value: _formatDuration(
                              widget.trip.duration), // REAL DATA
                          icon: Icons.timer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Transport',
                          value: widget.trip.transportMode.name
                              .toUpperCase(), // REAL DATA
                          icon: Icons.directions_car,
                        ),
                        _StatItem(
                          label: 'Avg Speed',
                          value:
                              '${(_averageSpeed * 3.6).toStringAsFixed(1)} km/h', // CALCULATED FROM REAL DATA
                          icon: Icons.trending_flat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

// Speed graph (Professional fl_chart UI)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speed Over Time',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mock data - GPS analysis coming soon',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text('Time (minutes)'),
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _getSpeedData(),
                              isCurved: true,
                              color: Colors.deepPurple,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.deepPurple.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

// Transport mode pie chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transport Mode',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _getTransportModePieData(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: _getColorForMode(
                                widget.trip.transportMode.name.toUpperCase()),
                          ),
                          const SizedBox(width: 8),
                          Text(widget.trip.transportMode.name.toUpperCase()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Color _getColorForMode(String mode) {
    switch (mode) {
      case 'DRIVING':
        return Colors.blue;
      case 'CYCLING':
        return Colors.green;
      case 'WALKING':
        return Colors.orange;
      case 'BUS':
        return Colors.green;
      case 'TRAIN':
        return Colors.red;
      case 'STILL':
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

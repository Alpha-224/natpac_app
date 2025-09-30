import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models.dart';
import '../../home/bloc/trip_bloc.dart';
import '../../home/bloc/trip_event.dart';
import '../../home/bloc/trip_state.dart';
import '../../trip_history/screens/trip_details_screen.dart';
import '../../trip_tracking/screens/advanced/analytics_screen.dart';

class TripHistoryScreen extends StatelessWidget {
const TripHistoryScreen({super.key});

String _formatDate(DateTime date) {
final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
final yesterday = today.subtract(const Duration(days: 1));
final tripDate = DateTime(date.year, date.month, date.day);

if (tripDate == today) {
return 'Today';
} else if (tripDate == yesterday) {
return 'Yesterday';
} else {
final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
}

String _formatTime(DateTime dateTime) {
final hour = dateTime.hour;
final minute = dateTime.minute;
final ampm = hour >= 12 ? 'PM' : 'AM';
final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
return '$displayHour:${minute.toString().padLeft(2, '0')} $ampm';
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

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Trip History'),
backgroundColor: Colors.deepPurple,
foregroundColor: Colors.white,
centerTitle: true,
actions: [
IconButton(
icon: const Icon(Icons.refresh),
onPressed: () {
context.read<TripBloc>().add(const LoadTrips());
},
),
],
),
body: BlocBuilder<TripBloc, TripState>(
builder: (context, state) {
if (state is TripLoading) {
return const Center(
child: CircularProgressIndicator(color: Colors.deepPurple),
);
} else if (state is TripLoaded) {
if (state.allTrips.isEmpty) {
return const Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.history, size: 64, color: Colors.grey),
SizedBox(height: 16),
Text('No trips recorded yet', 
style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
SizedBox(height: 8),
Text('Start tracking your trips to see them here!',
style: TextStyle(color: Colors.grey)),
],
),
);
}

return ListView.builder(
padding: const EdgeInsets.all(16.0),
itemCount: state.allTrips.length,
itemBuilder: (context, index) {
final trip = state.allTrips[index];
return Card(
margin: const EdgeInsets.only(bottom: 12),
elevation: 2,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
child: ListTile(
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
leading: Container(
width: 48,
height: 48,
decoration: BoxDecoration(
color: _getTransportModeColor(trip.transportMode).withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(24),
),
child: Icon(
_getTransportModeIcon(trip.transportMode),
color: _getTransportModeColor(trip.transportMode),
size: 24,
),
),
title: Text(
'${trip.originName} → ${trip.destinationName}',
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 16,
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
),
subtitle: Padding(
padding: const EdgeInsets.only(top: 8.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// First row: Distance and Duration
Row(
children: [
Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
const SizedBox(width: 4),
Text('${trip.distanceInKm.toStringAsFixed(2)} km'),
const SizedBox(width: 16),
Icon(Icons.timer, size: 14, color: Colors.grey[600]),
const SizedBox(width: 4),
Text(_formatDuration(trip.duration)),
],
),
const SizedBox(height: 4),
// Second row: Date and Transport Mode
Row(
children: [
Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
const SizedBox(width: 4),
Text(_formatDate(trip.timestamp)),
const SizedBox(width: 16),
Icon(_getTransportModeIcon(trip.transportMode), 
size: 14, color: Colors.grey[600]),
const SizedBox(width: 4),
Text(_getTransportModeLabel(trip.transportMode)),
],
),
],
),
),
trailing: PopupMenuButton<String>(
onSelected: (value) {
switch (value) {
case 'details':
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => TripDetailsScreen(trip: trip),
),
);
break;
case 'analytics':
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => AnalyticsScreen(trip: trip),
),
);
break;
case 'delete':
_showDeleteDialog(context, trip);
break;
}
},
itemBuilder: (context) => [
const PopupMenuItem(
value: 'details',
child: ListTile(
leading: Icon(Icons.info, color: Colors.blue),
title: Text('Trip Details'),
contentPadding: EdgeInsets.zero,
),
),
const PopupMenuItem(
value: 'analytics',
child: ListTile(
leading: Icon(Icons.analytics, color: Colors.deepPurple),
title: Text('Analytics'),
contentPadding: EdgeInsets.zero,
),
),
const PopupMenuItem(
value: 'delete',
child: ListTile(
leading: Icon(Icons.delete, color: Colors.red),
title: Text('Delete Trip'),
contentPadding: EdgeInsets.zero,
),
),
],
child: Container(
padding: const EdgeInsets.all(8),
child: Icon(
Icons.more_vert,
color: Colors.grey[600],
),
),
),
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => TripDetailsScreen(trip: trip),
),
);
},
),
);
},
);
} else if (state is TripError) {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.error_outline,
size: 64,
color: Colors.red[400],
),
const SizedBox(height: 16),
Text(
'Error Loading Trips',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w500,
color: Colors.red[600],
),
),
const SizedBox(height: 8),
Text(
state.message,
textAlign: TextAlign.center,
style: const TextStyle(color: Colors.grey),
),
const SizedBox(height: 16),
ElevatedButton.icon(
onPressed: () {
context.read<TripBloc>().add(const LoadTrips());
},
icon: const Icon(Icons.refresh),
label: const Text('Retry'),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.deepPurple,
foregroundColor: Colors.white,
),
),
],
),
);
}
return const Center(child: Text('Unknown state'));
},
),
);
}

void _showDeleteDialog(BuildContext context, Trip trip) {
showDialog(
context: context,
builder: (BuildContext dialogContext) {
return AlertDialog(
title: const Text('Delete Trip'),
content: Text(
'Are you sure you want to delete the trip from ${trip.originName} to ${trip.destinationName}?',
),
actions: [
TextButton(
onPressed: () => Navigator.of(dialogContext).pop(),
child: const Text('Cancel'),
),
TextButton(
onPressed: () {
Navigator.of(dialogContext).pop();
context.read<TripBloc>().add(DeleteTrip(tripId: trip.id));
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Trip deleted: ${trip.originName} → ${trip.destinationName}'),
backgroundColor: Colors.red,
action: SnackBarAction(
label: 'UNDO',
textColor: Colors.white,
onPressed: () {
context.read<TripBloc>().add(AddTrip(trip: trip));
},
),
),
);
},
style: TextButton.styleFrom(foregroundColor: Colors.red),
child: const Text('Delete'),
),
],
);
},
);
}
}

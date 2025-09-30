import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
final String tripId;

const MapScreen({
super.key,
required this.tripId,
});

@override
State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Trip Map'),
backgroundColor: Colors.deepPurple,
foregroundColor: Colors.white,
),
body: const Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.map,
size: 64,
color: Colors.deepPurple,
),
SizedBox(height: 16),
Text(
'Professional Map View',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
color: Colors.deepPurple,
),
),
Text('Coming Soon'),
],
),
),
);
}
}

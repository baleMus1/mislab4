import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleMapService extends StatefulWidget {
  final List<LatLng> locations;
  final String subject;

  const GoogleMapService({super.key, required this.locations, required this.subject});

  @override
  _GoogleMapServiceState createState() => _GoogleMapServiceState();
}

class _GoogleMapServiceState extends State<GoogleMapService> {
  late GoogleMapController _controller;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};

  final LatLng Skopje = const LatLng(41.995689,21.410220); // Default Skopje coordinates

  @override
  void initState() {
    super.initState();

    // Add all exam locations as markers
    for (int i = 0; i < widget.locations.length; i++) {
      final examLocation = widget.locations[i];
      _markers.add(
        Marker(
          markerId: MarkerId('examLocation$i'),
          position: examLocation,
          infoWindow: InfoWindow(
            title: '${widget.subject} $i',
            snippet: 'Subject: ${widget.subject} - Location: ${examLocation.latitude}, ${examLocation.longitude}',
          ),
          onTap: () {
            _onMarkerTapped(examLocation);  // Get route when marker tapped
          },
        ),
      );
    }

    _getUserLocationAndRoute();  // Get user's location and route
  }

  // Function to get the current location of the user and draw the route
  Future<void> _getUserLocationAndRoute() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng userLocation = LatLng(position.latitude, position.longitude);

      if (userLocation.latitude == 0.0 || userLocation.longitude == 0.0) {
        userLocation = Skopje;  // Use Skopje as fallback
      }

      setState(() {
        // Clear any existing polylines
        _polylines.clear();

        _circles.add(Circle(
          circleId: CircleId('userLocation'),
          center: userLocation,
          radius: 100, // Set radius of the circle
          fillColor: Colors.blue.withOpacity(0.3),  // Blue with transparency
          strokeColor: Colors.blue,
          strokeWidth: 3,
        ));
      });
      
      // Calculate route to all exam locations
      for (LatLng examLocation in widget.locations) {
        List<LatLng> route = await _getRoute(userLocation, examLocation);
        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId('routeTo${examLocation.latitude},${examLocation.longitude}'),
            points: route,
            color: Colors.blue,
            width: 5,
          ));
        });
      }

      // Move the camera to the user's location
      _controller.animateCamera(CameraUpdate.newLatLng(userLocation));
    } catch (e) {
      print("Error getting user location: $e");
    }
  }

  // Function to handle the route calculation when a marker is tapped
  Future<void> _onMarkerTapped(LatLng examLocation) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng userLocation = LatLng(position.latitude, position.longitude);

      List<LatLng> route = await _getRoute(userLocation, examLocation);
      setState(() {
        // Clear previous polylines and add the route to the selected marker
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId('routeTo${examLocation.latitude},${examLocation.longitude}'),
          points: route,
          color: Colors.blue,
          width: 5,
        ));
      });

      // Move the camera to the selected exam location
      _controller.animateCamera(CameraUpdate.newLatLng(examLocation));
    } catch (e) {
      print("Error getting route: $e");
    }
  }

  // Function to get the route from the Directions API
  Future<List<LatLng>> _getRoute(LatLng origin, LatLng destination) async {
    final originString = '${origin.latitude},${origin.longitude}';
    final destinationString = '${destination.latitude},${destination.longitude}';
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=$originString&destination=$destinationString&key=$apiKey'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<LatLng> route = [];

      if (data['routes'].isNotEmpty) {
        final points = data['routes'][0]['legs'][0]['steps'];
        for (var point in points) {
          final lat = point['end_location']['lat'];
          final lng = point['end_location']['lng'];
          route.add(LatLng(lat, lng));
        }
      }

      return route;
    } else {
      throw Exception('Failed to load directions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Location'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: Skopje, // Initially focus on Skopje or user location
          zoom: 14.4746,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}

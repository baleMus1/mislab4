import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'models/raspored.dart';
import 'services/googlemaps.dart';
import 'services/notification_service.dart';
import 'services/geolocator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  await dotenv.load(fileName: '.env');
  print('API Key: ${dotenv.env['GOOGLE_MAPS_API_KEY']}');
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService notificationService = NotificationService();
  await notificationService.initialize();
  runApp(const MyApp());
  tz.initializeTimeZones();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Exam Calendar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'Exam Schedule'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late DateTime _selectedDay;
  late List<ExamSchedule> _events;
  late TextEditingController _subjectController;
  late TextEditingController _locationController;
  LatLng? _userLocation;

  get notificationService => null;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _events = [];
    _subjectController = TextEditingController();
    _locationController = TextEditingController();
    _getCurrentLocation();
  }

  // Function to fetch the user's current location
  void _getCurrentLocation() async {
    try {
      Position position = await GeolocatorService.getCurrentLocation();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      // print("Error getting location: $e");
    }
  }
  Future<LatLng> _getCoordinatesFromAddress(String address) async {
    try {
      // Use geocoding to get coordinates from the address
      List<Location> locations = await locationFromAddress(address);
      // If multiple locations are found, return the first one
      if (locations.isNotEmpty) {
        return LatLng(locations[0].latitude, locations[0].longitude);
      } else {
        throw Exception('Address not found');
      }
    } catch (e) {
      throw Exception('Error getting coordinates: $e');
    }
  }

  void _addExamEvent() async {
    if (_subjectController.text.isNotEmpty && _locationController.text.isNotEmpty) {
      try {
        // Get the coordinates from the address
        LatLng examLocation = await _getCoordinatesFromAddress(_locationController.text);

        final newEvent = ExamSchedule(
          dateTime: _selectedDay,
          location: _locationController.text,
          subject: _subjectController.text,
          latitude: examLocation.latitude,
          longitude: examLocation.longitude,
        );
        setState(() {
          _events.add(newEvent);
        });

        // Schedule notification
        notificationService.scheduleNotification(_selectedDay);
      } catch (e) {
        // Handle address-to-coordinates error
        print('Error adding exam event: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _selectedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            selectedDayPredicate: (day) {
              return isSameDay(day,_selectedDay);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                ElevatedButton(
                  onPressed: _addExamEvent,
                  child: const Text('Add Exam'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final exam = _events[index];
                return ListTile(
                  title: Text(exam.subject),
                  subtitle: Text('${exam.location} at ${exam.dateTime}'),
                  onTap: () async {
                    // Open Google Maps and pass a list of the clicked location
                    final location = LatLng(exam.latitude, exam.longitude); // Convert to LatLng
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoogleMapService(
                          locations: [location],  // Pass the location as a list
                          subject: exam.subject,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

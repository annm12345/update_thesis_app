import 'dart:io';
import 'dart:math' as math;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mm_t/lattomgrs.dart';
import 'package:mm_t/mgrstolatlang.dart';
import 'package:mm_t/weapon.dart';
import 'dart:ui' as ui;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  String currentMap = 'OpenTopoMap';
  bool _isSettingTarget = false;
  LatLng? _firstPoint;
  LatLng? _secondPoint;
  List<LatLng> _polylinePoints = [];
  LatLng? _savedLocation; // For storing the saved location
  String _savedLocationLabel =
      ''; // For storing the label of the saved location
  double _firingRangeRadius = 0.0; // Firing range radius in meters
  bool _drawFiringRange = false; // Whether to draw the firing range circle
  List<Map<String, dynamic>> _circles = [];

  MapController _mapController = MapController();
  LatLng _currentLocation =
      LatLng(22.001, 96.083); // Default location (Myanmar)
  LatLng _centerCoordinates = LatLng(22.001, 96.083);
  TextEditingController _searchController = TextEditingController();

  final String openTopoMapUrl =
      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
  final String googleHybridMapUrl =
      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';

  @override
  void initState() {
    super.initState();
    _goToCurrentLocation();
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    _mapController.move(_currentLocation, 15.0);
  }

  void _searchLocation() {
    String mgrs = _searchController.text;
    if (mgrs.isNotEmpty) {
      LatLng latLng = mgrsToLatLng(mgrs);
      if (latLng != null) {
        setState(() {
          _currentLocation = latLng;
          _mapController.move(_currentLocation, 15.0);
        });
      } else {
        // Handle invalid MGRS input
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invalid MGRS input'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation,
              zoom: 7.0,
              minZoom: currentMap == 'OpenTopoMap'
                  ? 7.0
                  : 7.0, // Same minZoom for both
              maxZoom:
                  currentMap == 'OpenTopoMap' ? 17.0 : 18.0, // Dynamic maxZoom
              onTap: (tapPosition, point) {
                if (_isSettingTarget) {
                  _handleMapTap(point);
                }
              },
              onPositionChanged: (MapPosition position, bool hasGesture) {
                if (position.center != null) {
                  setState(() {
                    _centerCoordinates = position.center!;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: currentMap == 'OpenTopoMap'
                    ? openTopoMapUrl
                    : googleHybridMapUrl,
                subdomains: ['a', 'b', 'c'],
              ),
              if (_drawFiringRange) CircleLayer(circles: _buildCircles()),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    builder: (ctx) => const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  ..._buildCircleCenters(),
                  if (_firstPoint != null)
                    Marker(
                      point: _firstPoint!,
                      builder: (ctx) => const Icon(
                        Icons.circle,
                        color: Colors.blue,
                        size: 12,
                      ),
                    ),
                  if (_secondPoint != null)
                    Marker(
                      point: _secondPoint!,
                      builder: (ctx) => const Icon(
                        Icons.circle,
                        color: Colors.green,
                        size: 12,
                      ),
                    ),
                  if (_savedLocation != null)
                    Marker(
                      point: _savedLocation!,
                      builder: (ctx) => const Icon(
                        Icons.location_on,
                        color: Colors.orange,
                        size: 30,
                      ),
                    ),
                ],
              ),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue, // Adjust the color as needed
                    ),
                  ],
                ),
            ],
          ),
          Center(
            child: GestureDetector(
              onTap: () {
                _handleCenterDotTap();
              },
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(197, 5, 125, 224),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 5,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                ' ${MGRS.latLonToMGRS(_centerCoordinates.latitude, _centerCoordinates.longitude)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 16.0,
            left: 16.0,
            child: Row(
              children: [
                FloatingActionButton(
                  onPressed: _toggleMap,
                  backgroundColor: Colors.blue,
                  child: Icon(
                    currentMap == 'OpenTopoMap' ? Icons.map : Icons.satellite,
                  ),
                ),
                const SizedBox(width: 8.0), // Spacing between buttons
                FloatingActionButton(
                  onPressed: _showOptions, // Method to show options
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons
                      .space_dashboard_outlined), // Menu icon for "Options"
                ),
                const SizedBox(width: 8.0), // Spacing between buttons
                FloatingActionButton(
                  onPressed:
                      _toggleFiringRange, // Method to toggle firing range
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons
                      .add_circle_outline), // Icon for drawing firing range
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              backgroundColor: Colors.green,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 80.0,
            left: 16.0,
            right: 16.0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                color: const Color.fromARGB(148, 15, 205, 15),
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Enter MGRS Location', // Placeholder text
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: _searchLocation,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMap() {
    setState(() {
      currentMap = currentMap == 'OpenTopoMap' ? 'GoogleHybrid' : 'OpenTopoMap';
    });
  }

  void _toggleFiringRange() async {
    String? selectedRange = await _showFiringRangeDialog();
    if (selectedRange != null) {
      setState(() {
        _drawFiringRange = true;
      });
    }
  }

  List<CircleMarker> _buildCircles() {
    List<CircleMarker> circleMarkers = [];
    for (var circle in _circles) {
      final latitude = circle['latitude'] ?? 0.0;
      final longitude = circle['longitude'] ?? 0.0;
      final radius = circle['radius'] ?? 100.0;

      final circleMarker = CircleMarker(
        point: LatLng(latitude, longitude),
        radius: _metersToPixels(radius, _mapController.zoom, latitude),
        color: Colors.transparent, // No fill color
        borderStrokeWidth: 2,
        borderColor: Colors.blue, // Circle border color
      );

      circleMarkers.add(circleMarker);
    }
    return circleMarkers;
  }

  double _metersToPixels(double meters, double? zoom, double latitude) {
    if (zoom == null) return 0.0;
    double scale = (1 << zoom.toInt()).toDouble();
    double metersPerPixel =
        (156543.03392 * math.cos(latitude * math.pi / 180)) / scale;
    return meters / metersPerPixel;
  }

  List<Marker> _buildCircleCenters() {
    List<Marker> markers = [];
    for (var circle in _circles) {
      final latitude = circle['latitude'] ?? 0.0;
      final longitude = circle['longitude'] ?? 0.0;
      final point = LatLng(latitude, longitude);

      markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: point,
          builder: (ctx) => GestureDetector(
            onTap: () => _showRemoveCircleDialog(point),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40.0,
                  height: 40.0,
                  child: Icon(
                    Icons.circle,
                    color: const Color.fromARGB(0, 33, 149, 243),
                    size: 16.0,
                  ),
                ),
                Positioned(
                  child: Icon(
                    Icons.flag_circle_outlined,
                    color: const Color.fromARGB(255, 241, 221, 4),
                    size: 34.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _removeCircle(LatLng location) {
    setState(() {
      _circles.removeWhere((circle) =>
          circle['latitude'] == location.latitude &&
          circle['longitude'] == location.longitude);
    });
  }

  void _showRemoveCircleDialog(LatLng point) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Remove Circle"),
        content: Text("Do you want to remove this circle?"),
        actions: <Widget>[
          TextButton(
            child: Text("Cancel"),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: Text("Remove"),
            onPressed: () {
              _removeCircle(point);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _addCircle(LatLng location, double radius) {
    setState(() {
      _circles.add({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radius': radius,
      });
    });
  }

  Future<String?> _showFiringRangeDialog() {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Firing Range'),
          content: const Text('Choose MA7 or MA8 for firing range.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _addCircle(_centerCoordinates, 4600); // Add MA7 range
                Navigator.of(context).pop('MA7');
              },
              child: const Text('MA7'),
            ),
            TextButton(
              onPressed: () {
                _addCircle(_centerCoordinates, 6350); // Add MA8 range
                Navigator.of(context).pop('MA8');
              },
              child: const Text('MA8'),
            ),
          ],
        );
      },
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.zoom_in),
                title: const Text('Zoom In'),
                onTap: () {
                  _mapController.move(
                      _mapController.center, _mapController.zoom + 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.zoom_out),
                title: const Text('Zoom Out'),
                onTap: () {
                  _mapController.move(
                      _mapController.center, _mapController.zoom - 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers),
                title: const Text('Change Map Layer'),
                onTap: () {
                  _toggleMap();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timeline_rounded),
                title: const Text('Set Target'),
                onTap: () {
                  setState(() {
                    _isSettingTarget = true;
                    _firstPoint = null;
                    _secondPoint = null;
                  });
                  Navigator.pop(context);
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   const SnackBar(
                  //     content: Text('Tap on two locations to set the target.'),
                  //     duration: Duration(seconds: 1), // Display for 1 second
                  //   ),
                  // );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  double haversineDistance(LatLng point1, LatLng point2) {
    const earthRadiusKm = 6371.0; // Radius of the Earth in kilometers
    final dLat = radians(point2.latitude - point1.latitude);
    final dLon = radians(point2.longitude - point1.longitude);

    final a = pow(sin(dLat / 2), 2) +
        cos(radians(point1.latitude)) *
            cos(radians(point2.latitude)) *
            pow(sin(dLon / 2), 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double radians(double degrees) => degrees * (pi / 180);

  void _handleMapTap(LatLng point) {
    if (_firstPoint == null) {
      setState(() {
        _firstPoint = point;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('First point selected. Tap the second point.'),
      //     duration: Duration(seconds: 1),
      //   ),
      // );
    } else if (_secondPoint == null) {
      setState(() {
        _secondPoint = point;
        _isSettingTarget = false; // Exit "Set Target" mode

        // Add points to polyline
        _polylinePoints = [_firstPoint!, _secondPoint!];
      });

      if (_firstPoint != null && _secondPoint != null) {
        final distance = haversineDistance(_firstPoint!, _secondPoint!);
        final bearing = calculateBearing(_firstPoint!, _secondPoint!);
        final bearingInMils = (bearing * 17.7777777778).toStringAsFixed(2);
        // Find the suitable weapon
        final suitableWeapon =
            findSuitableWeapon(distance * 1000); // Convert km to meters

        if (suitableWeapon != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'အကွာအဝေး : ${distance.toStringAsFixed(2)} km\n'
                'ညွှန်းရပ်မေးလ်: $bearingInMils mils\n'
                'Suitable Weapon: ${suitableWeapon.name}\n'
                'Range: ${suitableWeapon.range} meters\n'
                'Gun Power: ${suitableWeapon.gunPower}\n'
                'Bullet Flight Time: ${suitableWeapon.bulletFlightTime} seconds\n'
                'Long Distance: ${suitableWeapon.longDistance} meters',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('အကွာအဝေး : ${distance.toStringAsFixed(2)} km\n'
                  'ညွှန်းရပ်မေးလ်: $bearingInMils mils\n'
                  'No suitable weapon found for this distance.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _handleCenterDotTap() {
    final centerPoint = _centerCoordinates;

    if (_savedLocation == null) {
      // Calculate distance from the current location to the center point
      // final distance = haversineDistance(_currentLocation, centerPoint);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Distance: ${distance.toStringAsFixed(2)} km'),
      //   ),
      // );

      // Prompt to save the location
      _showSaveLocationDialog(centerPoint);
    } else {
      // // Calculate distance from the saved location to the center point
      // final distance = haversineDistance(_savedLocation!, centerPoint);

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //         'Distance from $_savedLocationLabel: ${distance.toStringAsFixed(2)} km'),
      //   ),
      // );
    }
  }

  void _showSaveLocationDialog(LatLng location) {
    final TextEditingController labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save or Calculate Distance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Enter a label for this location or calculate distance.'),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Enter a label (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Save location logic
                setState(() {
                  _savedLocation = location;
                  _savedLocationLabel = labelController.text.isNotEmpty
                      ? labelController.text
                      : 'Saved Location';
                });

                Navigator.pop(context); // Close the dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Location saved as $_savedLocationLabel'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                final centerPoint = _centerCoordinates;

                // Calculate distance and bearing
                final distance =
                    haversineDistance(_currentLocation, centerPoint);
                final bearing = calculateBearing(_currentLocation, centerPoint);
                final bearingInMils =
                    (bearing * 17.7777777778).toStringAsFixed(2);

                // Find the suitable weapon
                final suitableWeapon =
                    findSuitableWeapon(distance * 1000); // Convert km to meters

                if (suitableWeapon != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'အကွာအဝေး : ${distance.toStringAsFixed(2)} km\n'
                        'ညွှန်းရပ်မေးလ်: $bearingInMils mils\n'
                        'Suitable Weapon: ${suitableWeapon.name}\n'
                        'Range: ${suitableWeapon.range} meters\n'
                        'Gun Power: ${suitableWeapon.gunPower}\n'
                        'Bullet Flight Time: ${suitableWeapon.bulletFlightTime} seconds\n'
                        'Long Distance: ${suitableWeapon.longDistance} meters',
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('အကွာအဝေး : ${distance.toStringAsFixed(2)} km\n'
                              'ညွှန်းရပ်မေးလ်: $bearingInMils mils\n'
                              'No suitable weapon found for this distance.'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              child: const Text('Distance & Find Weapon'),
            ),
          ],
        );
      },
    );
  }

  /// Calculate the bearing between two points in degrees
  double calculateBearing(LatLng start, LatLng end) {
    final lat1 = degreesToRadians(start.latitude);
    final lon1 = degreesToRadians(start.longitude);
    final lat2 = degreesToRadians(end.latitude);
    final lon2 = degreesToRadians(end.longitude);

    final dLon = lon2 - lon1;

    final x = math.sin(dLon) * math.cos(lat2);
    final y = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final initialBearing = radiansToDegrees(math.atan2(x, y));
    return (initialBearing + 360) % 360; // Normalize to 0-360 degrees
  }

  /// Convert degrees to radians
  double degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Convert radians to degrees
  double radiansToDegrees(double radians) {
    return radians * (180.0 / math.pi);
  }

  Weapon? findSuitableWeapon(double distance) {
    // Combine all weapons into one list for simplicity
    final List<Weapon> allWeapons = [...ma7Weapons, ...ma8Weapons];

    // Filter for weapons with a range that can handle the distance
    final suitableWeapons =
        allWeapons.where((weapon) => weapon.range >= distance).toList();

    if (suitableWeapons.isEmpty) {
      return null; // No suitable weapon found
    }

    // Find the weapon with the minimum range above the distance
    suitableWeapons.sort((a, b) => a!.range.compareTo(b?.range as num));

    return suitableWeapons.first; // Return the most suitable weapon
  }
}

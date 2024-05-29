import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? mapController;
  final LatLng _center = const LatLng(28.6129, 77.2295);
  Marker? _origin;
  Marker? _destination;
  Set<Polyline> _polylines = {};
  bool _isLoading = false;
  String _mapMessage = "Select Source";

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _addMarker(LatLng position) {
    if (_origin == null) {
      setState(() {
        _origin = Marker(
          markerId: const MarkerId("origin"),
          position: position,
          draggable: true,
          infoWindow: const InfoWindow(title: "Origin"),
        );
        _mapMessage = "Select Destination";
      });
    } else if (_destination == null) {
      setState(() {
        _destination = Marker(
          markerId: const MarkerId("destination"),
          position: position,
          draggable: true,
          infoWindow: const InfoWindow(title: "Destination"),
        );
        _mapMessage = "Fetching Route...";
        _isLoading = true;
      });
      _getDirections();
    }
  }

  Future<void> _getDirections() async {
    if (_origin == null || _destination == null) return;

    final origin = _origin!.position;
    final destination = _destination!.position;
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=AIzaSyDlyvDZQbwT6O9iNNA5wdKp8z62o2cxEzs');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final points = data['routes'][0]['overview_polyline']['points'];
        final List<LatLng> polylineCoordinates = _decodePolyline(points);
        setState(() {
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            visible: true,
            points: polylineCoordinates,
            width: 5,
            color: Colors.blue,
          ));
          _mapMessage = "Route Displayed";
          _isLoading = false;
        });
      }
    }
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> polylineCoordinates = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = polyline.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        byte = polyline.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylineCoordinates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mapMessage),
        actions: <Widget>[
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(target: _center, zoom: 11.0),
        markers: Set<Marker>.from([
          if (_origin != null) _origin!,
          if (_destination != null) _destination!
        ]),
        polylines: _polylines,
        onTap: _addMarker,
      ),
    );
  }
}

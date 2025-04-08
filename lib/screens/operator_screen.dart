import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../env/env.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  final supabase = Supabase.instance.client;
  bool _isSharing = false;
  String? busId;
  LatLng? currentLocation;
  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _checkPermissions();
    await fetchBusId();
    //await getCurrentLocation();
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> fetchBusId() async {
    final userId = supabase.auth.currentUser?.id;
    final response =
        await supabase
            .from('buses')
            .select('id')
            .eq('operator_id', userId)
            .maybeSingle();

    if (!mounted) return;
    if (response != null) {
      setState(() {
        busId = response['id'];
      });
    }
  }

  void _toggleSharing() {
    if (_isSharing) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) {
        sendLocationToSupabase();
      });
    }
    setState(() => _isSharing = !_isSharing);
  }

  Future<void> sendLocationToSupabase() async {
    if (busId == null || currentLocation == null) return;

    await supabase.from('locations').upsert({
      'bus_id': busId,
      'latitude': currentLocation!.latitude,
      'longitude': currentLocation!.longitude,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  void _sendAlert(String type) async {
    if (busId == null) return;
    await supabase.from('traffic_alerts').insert({
      'bus_id': busId,
      'type': type,
      'message': '$type reportado',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type enviado'), backgroundColor: Colors.black),
    );
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        mapController.move(currentLocation!, 15);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child:
            currentLocation == null
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6E39B5)),
                )
                : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Dashboard',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 250,
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: currentLocation!,
                              initialZoom: 15,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${Env.mapboxToken}',
                                userAgentPackageName: 'com.example.busapp',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: currentLocation!,
                                    width: 60,
                                    height: 60,
                                    child: Image.asset(
                                      'lib/assets/bus_icon.png',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildIconButton(
                              color: Colors.black,
                              icon: _isSharing ? Icons.pause : Icons.play_arrow,
                              label: _isSharing ? "Detener" : "Iniciar",
                              onTap: _toggleSharing,
                            ),
                            _buildIconButton(
                              color: Colors.yellow,
                              icon: Icons.warning,
                              label: "Tráfico",
                              onTap: () => _sendAlert("trafico"),
                            ),
                            _buildIconButton(
                              color: Colors.red,
                              icon: Icons.build,
                              label: "Reparación",
                              onTap: () => _sendAlert("reparacion"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextButton("Cerrar Sesión", () {
                        supabase.auth.signOut();
                        Navigator.pushReplacementNamed(context, "/login");
                      }),
                      const SizedBox(height: 10),
                      _buildTextButton("Soporte", () {
                        // abrir soporte
                      }),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildIconButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Ink(
          decoration: ShapeDecoration(
            color: color,
            shape: const CircleBorder(),
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildTextButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

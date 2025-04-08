import 'dart:async';
import 'dart:math';
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
  // Configuración ajustable
  static const double _iconSize = 36.0; // Tamaño del icono del camión
  static const double _mapZoom = 16.5; // Nivel de zoom del mapa
  static const int _updateInterval =
      2; // Intervalo de actualización en segundos
  static const int _distanceFilter = 5; // Filtro de distancia en metros
  static const int _maxHistoryPoints = 8; // Puntos para cálculo de dirección

  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  bool _isSharing = false;
  String? busId;
  LatLng? currentLocation;
  List<LatLng> _locationHistory = [];
  double _bearing = 0;
  bool _isFlipped = false; // Controla si el icono está volteado
  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;

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
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _checkPermissions();
    await fetchBusId();
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
      _timer = Timer.periodic(const Duration(seconds: _updateInterval), (_) {
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

  double _calculateBearing(List<LatLng> locations) {
    if (locations.length < 2) return 0;

    final recent =
        locations.length > 3
            ? locations.sublist(locations.length - 3)
            : locations;

    double sumSin = 0;
    double sumCos = 0;

    for (int i = 1; i < recent.length; i++) {
      final from = recent[i - 1];
      final to = recent[i];

      final lat1 = from.latitude * pi / 180;
      final lon1 = from.longitude * pi / 180;
      final lat2 = to.latitude * pi / 180;
      final lon2 = to.longitude * pi / 180;

      final y = sin(lon2 - lon1) * cos(lat2);
      final x =
          cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1);
      final angle = atan2(y, x);

      sumSin += sin(angle);
      sumCos += cos(angle);
    }

    final avgAngle = atan2(sumSin, sumCos);
    return (avgAngle * 180 / pi + 360) % 360;
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _distanceFilter,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        // Actualizar historial
        _locationHistory.add(newLocation);
        if (_locationHistory.length > _maxHistoryPoints) {
          _locationHistory.removeAt(0);
        }

        currentLocation = newLocation;

        // Calcular dirección
        final newBearing = _calculateBearing(_locationHistory) * pi / 180;

        // Determinar si debe voltearse (dirección opuesta)
        if (_locationHistory.length > 2) {
          final angleChange = (newBearing - _bearing).abs();
          if (angleChange > pi / 2) {
            // Cambio brusco de dirección
            _isFlipped = !_isFlipped;
          }
        }

        _bearing = newBearing + pi / 2; // Ajuste base de 90°

        // Ajuste para alineación con carreteras principales
        if (_locationHistory.length > 4) {
          final modAngle = _bearing % (pi / 2);
          if (modAngle < pi / 6) {
            _bearing -= modAngle;
          } else if (modAngle > pi / 3) {
            _bearing += (pi / 2 - modAngle);
          }
        }
      });

      if (mounted) {
        _mapController.move(newLocation, _mapZoom);
      }
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
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: currentLocation!,
                              initialZoom: _mapZoom,
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
                                    width: _iconSize,
                                    height: _iconSize,
                                    child: Transform(
                                      transform:
                                          Matrix4.identity()
                                            ..rotateZ(_bearing)
                                            ..scale(
                                              _isFlipped ? -1.0 : 1.0,
                                              1.0,
                                            ),
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        'lib/assets/bus_icon.png',
                                        fit: BoxFit.contain,
                                      ),
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

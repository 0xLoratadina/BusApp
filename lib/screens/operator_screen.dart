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
  // Configuración de la aplicación
  static const double _iconSize = 40.0;
  static const double _mapZoom = 16.5;
  static const int _updateInterval = 2; // segundos para actualización
  static const int _distanceFilter = 5; // metros para actualización GPS
  static const int _smoothingPoints = 10; // puntos para cálculo de dirección
  static const double _smoothingFactor = 0.2; // factor de interpolación

  // Dependencias
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  // Estado de la aplicación
  bool _isSharing = false;
  String? busId;
  LatLng? currentLocation;
  LatLng? _targetLocation;
  final List<LatLng> _locationHistory = [];
  double _bearing = 0;
  double _displayBearing = 0;
  bool _isFlipped = false;

  // Controladores
  Timer? _updateTimer;
  Timer? _animationTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _checkLocationPermissions();
      await _loadBusData();
      _startLocationUpdates();
      _startAnimationEngine();
    } catch (e) {
      _showError('Error al iniciar: ${e.toString()}');
    }
  }

  void _cleanupResources() {
    _updateTimer?.cancel();
    _animationTimer?.cancel();
    _positionStream?.cancel();
    _mapController.dispose();
  }

  Future<void> _checkLocationPermissions() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('El servicio de ubicación está desactivado');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación permanentemente denegados');
      }
    } catch (e) {
      _showError('Error de permisos: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _loadBusData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response =
          await supabase
              .from('buses')
              .select('id')
              .eq('operator_id', userId)
              .maybeSingle();

      if (!mounted) return;
      if (response == null) throw Exception('No se encontró autobús asignado');

      setState(() => busId = response['id'] as String);
    } catch (e) {
      _showError('Error cargando datos: ${e.toString()}');
      rethrow;
    }
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _distanceFilter,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) => _handleNewPosition(position),
      onError: (e) => _showError('Error de ubicación: ${e.toString()}'),
    );
  }

  void _handleNewPosition(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      _targetLocation = newLocation;
      _locationHistory.add(newLocation);

      if (_locationHistory.length > _smoothingPoints) {
        _locationHistory.removeAt(0);
      }

      _calculateDirection();
      _adjustVehicleOrientation();
    });
  }

  void _calculateDirection() {
    if (_locationHistory.length < 2) return;

    double sumSin = 0, sumCos = 0;
    for (int i = 1; i < _locationHistory.length; i++) {
      final angle = _calculateAngle(
        _locationHistory[i - 1],
        _locationHistory[i],
      );
      sumSin += sin(angle);
      sumCos += cos(angle);
    }

    _bearing = atan2(sumSin, sumCos) + (pi / 2); // Ajuste para icono
  }

  double _calculateAngle(LatLng from, LatLng to) {
    final lat1 = from.latitude * (pi / 180);
    final lon1 = from.longitude * (pi / 180);
    final lat2 = to.latitude * (pi / 180);
    final lon2 = to.longitude * (pi / 180);

    final y = sin(lon2 - lon1) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1);
    return atan2(y, x);
  }

  void _adjustVehicleOrientation() {
    // Voltear icono si cambia de dirección
    if (_locationHistory.length > 2) {
      final angleChange = (_bearing - _displayBearing).abs();
      if (angleChange > pi / 2) {
        _isFlipped = !_isFlipped;
      }
    }

    // Alinear con ejes principales de carretera
    if (_locationHistory.length > 4) {
      final modAngle = _bearing % (pi / 4);
      if (modAngle < pi / 8) {
        _bearing -= modAngle;
      } else if (modAngle > 3 * pi / 8) {
        _bearing += (pi / 4 - modAngle);
      }
    }
  }

  void _startAnimationEngine() {
    _animationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) => _updateAnimation(),
    );
  }

  void _updateAnimation() {
    if (_targetLocation == null || currentLocation == null || !mounted) return;

    // Interpolación de posición
    final newLat =
        currentLocation!.latitude +
        (_targetLocation!.latitude - currentLocation!.latitude) *
            _smoothingFactor;
    final newLng =
        currentLocation!.longitude +
        (_targetLocation!.longitude - currentLocation!.longitude) *
            _smoothingFactor;

    // Interpolación de rotación
    final angleDiff = (_bearing - _displayBearing + pi) % (2 * pi) - pi;
    _displayBearing += angleDiff * _smoothingFactor;

    setState(() {
      currentLocation = LatLng(newLat, newLng);
      _mapController.move(currentLocation!, _mapZoom);
    });
  }

  void _toggleSharing() {
    setState(() => _isSharing = !_isSharing);

    if (_isSharing) {
      _updateTimer = Timer.periodic(
        const Duration(seconds: _updateInterval),
        (_) => _sendLocationUpdate(),
      );
    } else {
      _updateTimer?.cancel();
    }
  }

  Future<void> _sendLocationUpdate() async {
    try {
      if (busId == null || currentLocation == null) return;

      await supabase.from('locations').upsert({
        'bus_id': busId,
        'latitude': currentLocation!.latitude,
        'longitude': currentLocation!.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _showError('Error enviando ubicación: ${e.toString()}');
    }
  }

  void _sendAlert(String type) async {
    try {
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
    } catch (e) {
      _showError('Error enviando alerta: ${e.toString()}');
    }
  }

  void _showError(String message) {
    debugPrint(message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child:
            currentLocation == null
                ? _buildLoadingView()
                : _buildMainInterface(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF6E39B5)),
          SizedBox(height: 20),
          Text('Inicializando sistema...'),
        ],
      ),
    );
  }

  Widget _buildMainInterface() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildMap(),
          const SizedBox(height: 16),
          _buildControlPanel(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 250,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentLocation!,
            initialZoom: _mapZoom,
            interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                          ..rotateZ(_displayBearing)
                          ..scale(_isFlipped ? -1.0 : 1.0, 1.0),
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
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            color: Colors.black,
            icon: _isSharing ? Icons.pause : Icons.play_arrow,
            label: _isSharing ? "Detener" : "Iniciar",
            onTap: _toggleSharing,
          ),
          _buildControlButton(
            color: Colors.yellow,
            icon: Icons.warning,
            label: "Tráfico",
            onTap: () => _sendAlert("trafico"),
          ),
          _buildControlButton(
            color: Colors.red,
            icon: Icons.build,
            label: "Reparación",
            onTap: () => _sendAlert("reparacion"),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildTextButton("Cerrar Sesión", () {
          supabase.auth.signOut();
          Navigator.pushReplacementNamed(context, "/login");
        }),
        const SizedBox(height: 10),
        _buildTextButton("Soporte", () {
          // Acción de soporte
        }),
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

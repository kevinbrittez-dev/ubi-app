import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCwjNCVAeLvMq_P0eyS36IUORZSOZD_KW0",
        appId: "1:96664850127:android:0b324e7c26f574cde371ba",
        messagingSenderId: "96664850127",
        projectId: "ubicacion-app-21ff2",
        databaseURL: "https://ubicacion-app-21ff2-default-rtdb.firebaseio.com",
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final clave = prefs.getString('clave') ?? '';
    final hora = prefs.getInt('hora') ?? -1;
    final minuto = prefs.getInt('minuto') ?? -1;

    if (clave.isEmpty || hora == -1) return true;

    final now = DateTime.now();
    if (now.hour != hora || now.minute != minuto) return true;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );
      
      await FirebaseDatabase.instance
          .ref('ubicaciones/$clave')
          .set({'lat': pos.latitude, 'lng': pos.longitude, 'tiempo': now.millisecondsSinceEpoch});
    } catch (e) {
      debugPrint('Error: $e');
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCwjNCVAeLvMq_P0eyS36IUORZSOZD_KW0",
      appId: "1:96664850127:android:0b324e7c26f574cde371ba",
      messagingSenderId: "96664850127",
      projectId: "ubicacion-app-21ff2",
      databaseURL: "https://ubicacion-app-21ff2-default-rtdb.firebaseio.com",
    ),
  );
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UbicaApp',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _claveCtrl = TextEditingController();
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  bool _compartiendo = false;
  StreamSubscription? _locationStream;

  @override
  void initState() {
    super.initState();
    _cargarConfig();
    _pedirPermisos();
  }

  Future<void> _cargarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final clave = prefs.getString('clave') ?? '';
    final hora = prefs.getInt('hora') ?? 10;
    final minuto = prefs.getInt('minuto') ?? 0;
    
    setState(() {
      _claveCtrl.text = clave;
      _hora = TimeOfDay(hour: hora, minute: minuto);
    });
  }

  Future<void> _pedirPermisos() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _guardarConfig() async {
    if (_claveCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una clave')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clave', _claveCtrl.text);
    await prefs.setInt('hora', _hora.hour);
    await prefs.setInt('minuto', _hora.minute);

    await Workmanager().cancelAll();
    await Workmanager().registerPeriodicTask(
      'ubicacion_task',
      'ubicacion_task',
      frequency: const Duration(minutes: 1),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Configurado')),
    );
  }

  void _iniciarCompartir() async {
    if (_claveCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una clave')),
      );
      return;
    }

    setState(() => _compartiendo = true);
    _guardarConfig();

    _locationStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      FirebaseDatabase.instance
          .ref('ubicaciones/${_claveCtrl.text}')
          .set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'tiempo': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _detenerCompartir() {
    _locationStream?.cancel();
    setState(() => _compartiendo = false);
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _claveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UbicaApp - Compartir Ubicación')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clave:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _claveCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ej: familia123',
                enabled: !_compartiendo,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Hora de envío automático:', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: Text('${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.schedule),
              enabled: !_compartiendo,
              onTap: !_compartiendo
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _hora,
                      );
                      if (picked != null) {
                        setState(() => _hora = picked);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _compartiendo ? _detenerCompartir : _iniciarCompartir,
                style: FilledButton.styleFrom(
                  backgroundColor: _compartiendo ? Colors.red : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _compartiendo ? 'DETENER COMPARTIR' : 'EMPEZAR A COMPARTIR EN VIVO',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text('VER UBICACIÓN DEL OTRO:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_claveCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa una clave primero')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(clave: _claveCtrl.text),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'VER EN MAPA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final String clave;
  const MapScreen({super.key, required this.clave});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _ubicacion;
  final MapController _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    _escucharUbicacion();
  }

  void _escucharUbicacion() {
    FirebaseDatabase.instance
        .ref('ubicaciones/${widget.clave}')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map;
        final lat = (data['lat'] as num).toDouble();
        final lng = (data['lng'] as num).toDouble();
        setState(() => _ubicacion = LatLng(lat, lng));
        _mapCtrl.move(_ubicacion!, 16);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final centro = _ubicacion ?? const LatLng(-25.2867, -57.6470);

    return Scaffold(
      appBar: AppBar(title: Text('Ubicación: ${widget.clave}')),
      body: FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(initialCenter: centro, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.ubicacion.app',
          ),
          if (_ubicacion != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _ubicacion!,
                  width: 60,
                  height: 60,
                  child: const Icon(Icons.location_pin, color: Colors.red, size: 50),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

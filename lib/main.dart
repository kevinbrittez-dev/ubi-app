import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:flutter/services.dart';

final FlutterLocalNotificationsPlugin notifPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> mostrarNotif(String titulo, String cuerpo) async {
  const details = AndroidNotificationDetails(
    'ubicacion_ch', 'Ubicacion automatica',
    channelDescription: 'Avisos de compartir ubicacion',
    importance: Importance.high,
    priority: Priority.high,
  );
  await notifPlugin.show(
      0, titulo, cuerpo, const NotificationDetails(android: details));
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCwjNCVAeLvMq_P0eyS36IUORZSOZD_KW0",
          appId: "1:96664850127:android:0b324e7c26f574cde371ba",
          messagingSenderId: "96664850127",
          projectId: "ubicacion-app-21ff2",
          databaseURL:
              "https://ubicacion-app-21ff2-default-rtdb.firebaseio.com",
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final clave = prefs.getString('clave') ?? '';
      final autoOn = prefs.getBool('auto_enabled') ?? false;
      if (clave.isEmpty || !autoOn) return true;

      final now = DateTime.now();
      final diasGuardados = prefs.getStringList('dias') ?? [];
      if (!diasGuardados.contains(now.weekday.toString())) return true;

      final startH = prefs.getInt('inicio_hora') ?? 22;
      final startM = prefs.getInt('inicio_min') ?? 0;
      final endH = prefs.getInt('fin_hora') ?? 22;
      final endM = prefs.getInt('fin_min') ?? 30;
      final nowMin = now.hour * 60 + now.minute;
      final startMin = startH * 60 + startM;
      final endMin = endH * 60 + endM;

      if (nowMin < startMin || nowMin >= endMin) return true;

      // ✅ CAMBIO: ahora solo permite si tiene permiso "Todo el tiempo"
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always) return true;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await FirebaseDatabase.instance
          .ref('rooms/$clave')
          .set({'lat': pos.latitude, 'lng': pos.longitude});

      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      await notifPlugin.initialize(
          const InitializationSettings(android: androidInit));
      await mostrarNotif(
          'Compartiendo ubicacion', 'Envio automatico activo ahora');
    } catch (e) {
      debugPrint('Error tarea: $e');
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

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifPlugin
      .initialize(const InitializationSettings(android: androidInit));

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UbicaApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
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
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarClave();
  }

  Future<void> _cargarClave() async {
    final prefs = await SharedPreferences.getInstance();
    final clave = prefs.getString('ultima_clave') ?? '';
    setState(() => _ctrl.text = clave);
  }

  void _entrar(String rol) async {
    final clave = _ctrl.text.trim();
    if (clave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa una contrasena')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ultima_clave', clave);
    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MapScreen(clave: clave, rol: rol)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 90, color: Colors.blue),
              const SizedBox(height: 12),
              const Text('UbicaApp',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Ingresa la contrasena compartida',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Contrasena secreta',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _entrar('compartir'),
                  icon: const Icon(Icons.share_location),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('COMPARTIR MI UBICACION',
                        style: TextStyle(fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _entrar('ver'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.map),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('VER UBICACION DEL OTRO',
                        style: TextStyle(fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final String clave;
  final String rol;
  const MapScreen({super.key, required this.clave, required this.rol});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  LatLng? _miUbicacion;
  LatLng? _otraUbicacion;
  bool _compartiendo = false;
  late DatabaseReference _ref;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseDatabase.instance.ref('rooms/${widget.clave}');
    if (widget.rol == 'ver') {
      _escuchar();
    } else {
      _obtenerMiUbicacion();
    }
  }

  void _escuchar() {
    _ref.onValue.listen((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return;
      final raw = snapshot.value;
      double? lat;
      double? lng;
      if (raw is Map) {
        lat = (raw['lat'] as num?)?.toDouble();
        lng = (raw['lng'] as num?)?.toDouble();
      }
      if (lat != null && lng != null && mounted) {
        setState(() => _otraUbicacion = LatLng(lat!, lng!));
        _mapCtrl.move(_otraUbicacion!, 16);
      }
    });
  }

  Future<void> _obtenerMiUbicacion() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() => _miUbicacion = LatLng(pos.latitude, pos.longitude));
        _mapCtrl.move(_miUbicacion!, 16);
      }
    } catch (_) {}
  }

  Future<void> _toggleCompartir() async {
    if (_compartiendo) {
      setState(() {
        _compartiendo = false;
        _miUbicacion = null;
      });
      return;
    }
    bool ok = await Geolocator.isLocationServiceEnabled();
    if (!ok) { _snack('Activa el GPS'); return; }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _snack('Permiso de ubicacion denegado');
      return;
    }
    setState(() => _compartiendo = true);
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      if (!_compartiendo || !mounted) return;
      _ref.set({'lat': pos.latitude, 'lng': pos.longitude});
      setState(() => _miUbicacion = LatLng(pos.latitude, pos.longitude));
      _mapCtrl.move(_miUbicacion!, 16);
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final esCompartir = widget.rol == 'compartir';
    final centroMapa = esCompartir
        ? (_miUbicacion ?? const LatLng(-25.2867, -57.6470))
        : (_otraUbicacion ?? const LatLng(-25.2867, -57.6470));

    return Scaffold(
      appBar: AppBar(
        title: Text(esCompartir ? 'Compartiendo' : 'Viendo ubicacion'),
        actions: [
          if (esCompartir)
            IconButton(
              icon: const Icon(Icons.schedule),
              tooltip: 'Programar horario',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ConfigScreen(clave: widget.clave)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Icon(Icons.lock, size: 16),
              label: Text(widget.clave,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(initialCenter: centroMapa, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ubicacion.app',
              ),
              MarkerLayer(markers: [
                if (esCompartir && _miUbicacion != null)
                  Marker(
                    point: _miUbicacion!,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_pin,
                        color: Colors.blue, size: 52),
                  ),
                if (!esCompartir && _otraUbicacion != null)
                  Marker(
                    point: _otraUbicacion!,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_pin,
                        color: Colors.red, size: 52),
                  ),
              ]),
            ],
          ),
          if (esCompartir && _miUbicacion == null && !_compartiendo)
            const Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Presiona el boton azul\npara empezar a compartir',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          if (!esCompartir && _otraUbicacion == null)
            const Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Esperando ubicacion...\nEl otro debe entrar\ncon la misma clave\ny presionar COMPARTIR',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          if (esCompartir && _compartiendo)
            Positioned(
              top: 16, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_tethering, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Transmitiendo en vivo',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 90, right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(children: [
                      Icon(Icons.location_pin, color: Colors.blue, size: 20),
                      SizedBox(width: 4),
                      Text('Yo', style: TextStyle(fontSize: 13)),
                    ]),
                    Row(children: [
                      Icon(Icons.location_pin, color: Colors.red, size: 20),
                      SizedBox(width: 4),
                      Text('El otro', style: TextStyle(fontSize: 13)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: esCompartir
          ? FloatingActionButton.extended(
              onPressed: _toggleCompartir,
              backgroundColor: _compartiendo ? Colors.red : Colors.blue,
              icon: Icon(_compartiendo ? Icons.stop : Icons.share_location),
              label: Text(_compartiendo ? 'DETENER' : 'COMPARTIR'),
            )
          : null,
    );
  }
}

class ConfigScreen extends StatefulWidget {
  final String clave;
  const ConfigScreen({super.key, required this.clave});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  bool _autoEnabled = false;
  final Map<int, String> _nombresDias = {
    1: 'Lunes', 2: 'Martes', 3: 'Miercoles',
    4: 'Jueves', 5: 'Viernes', 6: 'Sabado', 7: 'Domingo',
  };
  final Set<int> _diasSeleccionados = {};
  TimeOfDay _inicio = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 22, minute: 30);
  bool _guardando = false;
  bool _bateriaExenta = false;

  static const _platform = MethodChannel('com.ubicacion.app/battery');

  // ✅ NUEVO MÉTODO: verifica y pide permiso "Todo el tiempo"
  Future<bool> _ensureBackgroundPermission() async {
    var perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    // Si está en "Mientras usas la app" → pedimos que lo cambie a "Todo el tiempo"
    if (perm == LocationPermission.whileInUse || perm == LocationPermission.denied) {
      final abrirSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permiso de background requerido'),
          content: const Text(
            'Para que la ubicación se envíe automáticamente (incluso con la pantalla apagada)\n'
            'necesitas elegir "Permitir todo el tiempo".\n\n'
            '¿Abrir ajustes de la app ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );

      if (abrirSettings == true) {
        await Geolocator.openAppSettings();
        await Future.delayed(const Duration(seconds: 2));
        perm = await Geolocator.checkPermission();
      }
    }

    return perm == LocationPermission.always;
  }

  @override
  void initState() {
    super.initState();
    _cargarConfig();
    _verificarBateria();
  }

  Future<void> _verificarBateria() async {
    try {
      final bool exenta = await _platform.invokeMethod('isIgnoringBatteryOptimizations');
      setState(() => _bateriaExenta = exenta);
    } catch (_) {}
  }

  Future<void> _solicitarExencionBateria() async {
    try {
      await _platform.invokeMethod('requestIgnoreBatteryOptimizations');
      await Future.delayed(const Duration(seconds: 2));
      await _verificarBateria();
    } catch (_) {}
  }

  Future<void> _cargarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final dias = prefs.getStringList('dias') ?? [];
    setState(() {
      _autoEnabled = prefs.getBool('auto_enabled') ?? false;
      _diasSeleccionados.addAll(dias.map(int.parse));
      _inicio = TimeOfDay(
        hour: prefs.getInt('inicio_hora') ?? 22,
        minute: prefs.getInt('inicio_min') ?? 0,
      );
      _fin = TimeOfDay(
        hour: prefs.getInt('fin_hora') ?? 22,
        minute: prefs.getInt('fin_min') ?? 30,
      );
    });
  }

  Future<void> _guardar() async {
    // ✅ NUEVA VALIDACIÓN: si activa automático, debe tener permiso always
    if (_autoEnabled) {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Permiso background no concedido'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_diasSeleccionados.isEmpty && _autoEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos un dia')));
      return;
    }
    setState(() => _guardando = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_enabled', _autoEnabled);
    await prefs.setString('clave', widget.clave);
    await prefs.setStringList(
        'dias', _diasSeleccionados.map((d) => d.toString()).toList());
    await prefs.setInt('inicio_hora', _inicio.hour);
    await prefs.setInt('inicio_min', _inicio.minute);
    await prefs.setInt('fin_hora', _fin.hour);
    await prefs.setInt('fin_min', _fin.minute);

    await Workmanager().cancelAll();

    if (_autoEnabled) {
      await Workmanager().registerPeriodicTask(
        'ubicacion_auto',
        'ubicacion_automatica',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      await mostrarNotif(
        'Horario guardado',
        'Compartire ubicacion automaticamente segun tu configuracion',
      );
    }

    setState(() => _guardando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_autoEnabled
              ? 'Horario automatico activado'
              : 'Horario automatico desactivado'),
          backgroundColor: _autoEnabled ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  Future<void> _elegirHora(bool esInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: esInicio ? _inicio : _fin,
    );
    if (picked != null) {
      setState(() => esInicio ? _inicio = picked : _fin = picked);
    }
  }

  String _formatHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horario automatico')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── AVISO BATERIA ──
          if (!_bateriaExenta)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.battery_alert, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Optimizacion de bateria activa',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      'Android puede bloquear el envio automatico. '
                      'Desactiva la optimizacion de bateria para esta app.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _solicitarExencionBateria,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange),
                      icon: const Icon(Icons.battery_charging_full),
                      label: const Text('Desactivar restriccion'),
                    ),
                  ],
                ),
              ),
            ),

          if (!_bateriaExenta) const SizedBox(height: 12),

          if (_bateriaExenta)
            Card(
              color: Colors.green.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Bateria configurada correctamente',
                      style: TextStyle(color: Colors.green,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),

          if (_bateriaExenta) const SizedBox(height: 12),

          Card(
            child: SwitchListTile(
              title: const Text('Activar envio automatico',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'La ubicación se compartira sola en el horario elegido'),
              value: _autoEnabled,
              onChanged: (v) async {
                setState(() => _autoEnabled = v);

                if (v) {
                  final tienePermiso = await _ensureBackgroundPermission();
                  if (!tienePermiso) {
                    setState(() => _autoEnabled = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Se necesita permiso "Todo el tiempo"'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dias de la semana',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _nombresDias.entries.map((e) {
                      final seleccionado = _diasSeleccionados.contains(e.key);
                      return FilterChip(
                        label: Text(e.value),
                        selected: seleccionado,
                        onSelected: _autoEnabled
                            ? (v) => setState(() => v
                                ? _diasSeleccionados.add(e.key)
                                : _diasSeleccionados.remove(e.key))
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Horario',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Inicio',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            FilledButton(
                              onPressed: _autoEnabled
                                  ? () => _elegirHora(true)
                                  : null,
                              child: Text(_formatHora(_inicio),
                                  style: const TextStyle(fontSize: 22)),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('a', style: TextStyle(fontSize: 24)),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Fin',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            FilledButton(
                              onPressed: _autoEnabled
                                  ? () => _elegirHora(false)
                                  : null,
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green),
                              child: Text(_formatHora(_fin),
                                  style: const TextStyle(fontSize: 22)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(33, 150, 243, 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El envio automatico se activa cada 15 minutos aprox. '
                    'Para mayor confiabilidad desactiva la restriccion de bateria.',
                    style: TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                    _guardando ? 'Guardando...' : 'GUARDAR CONFIGURACION',
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

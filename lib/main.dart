import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const navy = Color(0xFF0B1020);
const surface = Color(0xFF141C2F);
const blue = Color(0xFF1677FF);
const muted = Color(0xFF9BABC5);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Default to LAN IP if on local Wi-Fi, or fallback to localhost
  final defaultUrl = 'http://192.168.1.39:8000';
  Api.baseUrl = prefs.getString('baseUrl') ?? defaultUrl;
  runApp(const DrivePlusApp());
}

class Api {
  static String baseUrl = 'http://192.168.1.39:8000';
  static String token = '';
  static String email = '';
  static Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  static Future<bool> testConnection([String? candidateUrl]) async {
    final target = (candidateUrl ?? baseUrl).trim().replaceAll(RegExp(r'/$'), '');
    try {
      final res = await http.get(Uri.parse('$target/health')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? body, bool auth = true, Map<String, String>? query}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final u = uri(path, query);
    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(u, headers: headers).timeout(const Duration(seconds: 12));
          break;
        case 'POST':
          response = await http.post(u, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 12));
          break;
        case 'DELETE':
          response = await http.delete(u, headers: headers).timeout(const Duration(seconds: 12));
          break;
        default:
          throw Exception('Unsupported request');
      }
    } catch (e) {
      throw Exception(
        'Cannot reach backend at $baseUrl\n\n'
        '• If USB cable was removed, your phone and computer must be on the same Wi-Fi.\n'
        '• Enter your computer Wi-Fi IP address (e.g. http://192.168.1.39:8000).\n'
        '• Ensure Python backend is running (python run_server.py).',
      );
    }
    dynamic data;
    try {
      data = response.body.isEmpty ? {} : jsonDecode(response.body);
    } catch (_) {
      data = {'detail': response.body};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data is Map ? (data['detail'] ?? data['message'] ?? 'Request failed') : 'Request failed';
      throw Exception(detail.toString());
    }
    return data;
  }
}

class DrivePlusApp extends StatelessWidget {
  const DrivePlusApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DrivePlus',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: navy,
          colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark, surface: surface),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1B263C),
            hintStyle: const TextStyle(color: Color(0xFF9BABC5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: blue)),
          ),
          appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, elevation: 0),
        ),
        home: const AuthGate(),
      );
}

class ServerConfigDialog extends StatefulWidget {
  final VoidCallback? onSaved;
  const ServerConfigDialog({super.key, this.onSaved});
  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _controller;
  bool _testing = false;
  String? _statusMessage;
  bool? _success;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: Api.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final candidate = _controller.text.trim().replaceAll(RegExp(r'/$'), '');
    if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
      setState(() {
        _success = false;
        _statusMessage = 'Address must start with http:// or https://';
      });
      return;
    }
    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    final ok = await Api.testConnection(candidate);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _success = ok;
      _statusMessage = ok
          ? 'Connected! Backend is reachable.'
          : 'Could not connect. Ensure Python backend is running on 0.0.0.0:8000 and phone is on the same Wi-Fi.';
    });
  }

  Future<void> _save() async {
    var candidate = _controller.text.trim().replaceAll(RegExp(r'/$'), '');
    if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
      showMsg(context, 'URL must start with http:// or https://');
      return;
    }
    Api.baseUrl = candidate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', candidate);
    if (widget.onSaved != null) widget.onSaved!();
    if (mounted) {
      Navigator.of(context).pop();
      showMsg(context, 'Server updated: $candidate');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.dns_outlined, color: blue),
          SizedBox(width: 8),
          Text('Backend Server'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the address where the Python FastAPI backend is running:',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://192.168.1.39:8000',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Wi-Fi (192.168.1.39:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _controller.text = 'http://192.168.1.39:8000';
                      _statusMessage = null;
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _controller.text = 'http://10.0.2.2:8000';
                      _statusMessage = null;
                    });
                  },
                ),
                ActionChip(
                  label: const Text('USB adb reverse (127.0.0.1:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _controller.text = 'http://127.0.0.1:8000';
                      _statusMessage = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check, size: 18),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _success == true ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _success == true ? Colors.green : Colors.redAccent),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _success == true ? Icons.check_circle : Icons.error_outline,
                      size: 18,
                      color: _success == true ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _success == true ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save & Apply')),
      ],
    );
  }
}

Future<void> showServerConfigDialog(BuildContext context, {VoidCallback? onSaved}) {
  return showDialog(
    context: context,
    builder: (_) => ServerConfigDialog(onSaved: onSaved),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool busy = false, registering = false;
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final e = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      showMsg(context, 'Enter a valid email address');
      return;
    }
    if (password.text.length < (registering ? 6 : 1)) {
      showMsg(context, registering ? 'Password must be at least 6 characters' : 'Enter your password');
      return;
    }
    if (registering && name.text.trim().isEmpty) {
      showMsg(context, 'Enter your full name');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await Api.request(
        'POST',
        registering ? '/auth/register' : '/auth/login',
        auth: false,
        body: {'email': e, 'password': password.text, if (registering) 'full_name': name.text.trim()},
      );
      Api.token = (result['token'] ?? '').toString();
      Api.email = (result['email'] ?? e).toString();
      if (Api.token.isEmpty) throw Exception('Server did not return a login token');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceFirst('Exception: ', '');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 8),
                Text('Connection Issue'),
              ],
            ),
            content: Text(errText),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showServerConfigDialog(context, onSaved: () => setState(() {}));
                },
                child: const Text('Server Settings'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('DRIVEPLUS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_ethernet),
              tooltip: 'Backend Server Settings',
              onPressed: () => showServerConfigDialog(context, onSaved: () => setState(() {})),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registering ? 'Create your\naccount.' : 'Your drive.\nUnder control.',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      registering ? 'Start your DrivePlus journey.' : 'Manage vehicles, maintenance and every journey.',
                      style: const TextStyle(color: Color(0xFF9BABC5)),
                    ),
                    const SizedBox(height: 16),
                    Center(child: Image.asset('assets/driveplus_logo.png', height: 120, fit: BoxFit.contain)),
                    const SizedBox(height: 16),
                    // Server indicator and quick changer
                    InkWell(
                      onTap: () => showServerConfigDialog(context, onSaved: () => setState(() {})),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.dns_outlined, size: 20, color: blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Connected Server', style: TextStyle(fontSize: 11, color: muted)),
                                  Text(
                                    Api.baseUrl,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune, size: 14, color: Color(0xFF70ACFF)),
                                  SizedBox(width: 4),
                                  Text('Edit IP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF70ACFF))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (registering) ...[
                      TextField(controller: name, decoration: const InputDecoration(hintText: 'Full name')),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(hintText: 'Gmail / email address'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: InputDecoration(hintText: registering ? 'Password (6+ characters)' : 'Password'),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        child: busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(registering ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: busy ? null : () => setState(() => registering = !registering),
                        child: Text(
                          registering ? 'Already have an account? Sign in' : 'New to DrivePlus? Create an account',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Using phone without USB? Make sure Phone & PC are on the same Wi-Fi.',
                        style: TextStyle(fontSize: 11, color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final titles = ['Home', 'Vehicles', 'Services', 'Travel', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onNavigate: (i) => setState(() => index = i)),
      VehiclesPage(),
      ServicesPage(),
      TravelPage(),
      ProfilePage(onLogout: logout),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('DRIVEPLUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        actions: [
          if (index != 4)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => confirmSos(context),
                icon: const Icon(Icons.sos, color: Colors.white),
                label: const Text('SOS', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Vehicles'),
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Travel'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  void logout() {
    Api.token = '';
    Api.email = '';
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
  }
}

class PageWrap extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const PageWrap({super.key, required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Color(0xFF9BABC5))),
          const SizedBox(height: 20),
          child,
        ]),
      );
}

Widget actionCard({required IconData icon, required String title, required String detail, VoidCallback? onTap}) => Card(
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: blue.withValues(alpha: .15), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: const Color(0xFF70ACFF)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(detail, style: const TextStyle(color: Color(0xFF9BABC5), fontSize: 13)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );

Widget primaryButton(String label, VoidCallback? onPressed, {IconData? icon}) => SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon ?? Icons.check), label: Text(label)),
    );

void showMsg(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

class HomePage extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomePage({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context) => PageWrap(
        title: 'Good to see you 👋',
        subtitle: 'Your vehicle life, simplified.',
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0F4A97), Color(0xFF1677FF)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DRIVE SMARTER', style: TextStyle(color: Color(0xFFB4DAFF), fontWeight: FontWeight.bold, letterSpacing: 1.4)),
                  SizedBox(height: 10),
                  Text('Every mile,\nmanaged.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.05)),
                  SizedBox(height: 10),
                  Text('Your vehicles, service dates and trips in one place.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            actionCard(
              icon: Icons.directions_car,
              title: 'Vehicle garage',
              detail: 'Add vehicles and keep registration details handy.',
              onTap: () => onNavigate(1),
            ),
            actionCard(
              icon: Icons.build_circle_outlined,
              title: 'Service & insurance',
              detail: 'Keep maintenance and renewals on schedule.',
              onTap: () => onNavigate(2),
            ),
            actionCard(
              icon: Icons.route,
              title: 'Plan a trip',
              detail: 'Estimate fuel costs between two places.',
              onTap: () => onNavigate(3),
            ),
            actionCard(
              icon: Icons.health_and_safety_outlined,
              title: 'Emergency support',
              detail: 'Open maps or view safety information.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyPage())),
            ),
          ],
        ),
      );
}

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});
  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  bool loading = true;
  List<dynamic> vehicles = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await Api.request('GET', '/vehicles');
      vehicles = List<dynamic>.from(data as List);
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const VehicleDialog());
    if (result == null) return;
    try {
      await Api.request('POST', '/vehicles', body: result);
      if (mounted) {
        showMsg(context, 'Vehicle saved');
        load();
      }
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> remove(dynamic v) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: const Text('This also removes linked reminders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await Api.request('DELETE', '/vehicles/${v['id']}');
      load();
    } catch (e) {
      if (mounted) showMsg(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => PageWrap(
        title: 'Your garage',
        subtitle: 'Keep every vehicle in one place.',
        child: Column(
          children: [
            primaryButton('Add vehicle', add, icon: Icons.add),
            const SizedBox(height: 12),
            if (loading) const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
            if (!loading && vehicles.isEmpty)
              actionCard(icon: Icons.garage_outlined, title: 'Your garage is empty', detail: 'Add a car, bike or other vehicle to get started.'),
            ...vehicles.map(
              (v) => actionCard(
                icon: Icons.directions_car,
                title: '${v['brand'] ?? ''} ${v['model'] ?? ''}',
                detail: '${v['year'] ?? 'Year n/a'} · ${v['registration_number'] ?? ''}\nTank capacity: ${v['tank_capacity'] ?? '—'} L',
                onTap: () => remove(v),
              ),
            ),
          ],
        ),
      );
}

class VehicleDialog extends StatefulWidget {
  const VehicleDialog({super.key});
  @override
  State<VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<VehicleDialog> {
  final brand = TextEditingController(),
      model = TextEditingController(),
      year = TextEditingController(),
      reg = TextEditingController(),
      tank = TextEditingController();
  @override
  void dispose() {
    brand.dispose();
    model.dispose();
    year.dispose();
    reg.dispose();
    tank.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add vehicle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: brand, decoration: const InputDecoration(labelText: 'Brand')),
              const SizedBox(height: 10),
              TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
              const SizedBox(height: 10),
              TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year (optional)')),
              const SizedBox(height: 10),
              TextField(controller: reg, decoration: const InputDecoration(labelText: 'Registration number')),
              const SizedBox(height: 10),
              TextField(
                controller: tank,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tank capacity in litres (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (brand.text.trim().isEmpty || model.text.trim().isEmpty || reg.text.trim().isEmpty) {
                showMsg(context, 'Brand, model and registration are required');
                return;
              }
              Navigator.pop(context, {
                'brand': brand.text.trim(),
                'model': model.text.trim(),
                'year': int.tryParse(year.text),
                'registration_number': reg.text.trim(),
                'tank_capacity': double.tryParse(tank.text),
                'photo_uri': '',
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  bool loading = true;
  List<dynamic> reminders = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      reminders = List<dynamic>.from(await Api.request('GET', '/reminders') as List);
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const ReminderDialog());
    if (r == null) return;
    try {
      await Api.request('POST', '/reminders', body: r);
      load();
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => PageWrap(
        title: 'Service planner',
        subtitle: 'Maintenance and insurance reminders.',
        child: Column(
          children: [
            actionCard(icon: Icons.oil_barrel_outlined, title: 'Oil & routine service', detail: 'Add your next oil change, inspection or maintenance date.', onTap: add),
            actionCard(icon: Icons.shield_outlined, title: 'Insurance renewal', detail: 'Track policy renewal dates before they expire.', onTap: add),
            primaryButton('Add reminder', add, icon: Icons.add_alert),
            const SizedBox(height: 14),
            if (loading) const CircularProgressIndicator(),
            if (!loading && reminders.isEmpty) actionCard(icon: Icons.event_available, title: 'No reminders yet', detail: 'Add a date to start tracking service and renewals.'),
            ...reminders.map(
              (r) => actionCard(
                icon: Icons.notifications_active_outlined,
                title: '${r['title'] ?? 'Reminder'}',
                detail: '${r['due_date'] ?? ''} · ${r['category'] ?? 'service'}${(r['notes'] ?? '').toString().isEmpty ? '' : '\n${r['notes']}'}',
              ),
            ),
          ],
        ),
      );
}

class ReminderDialog extends StatefulWidget {
  const ReminderDialog({super.key});
  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  final title = TextEditingController(),
      date = TextEditingController(),
      category = TextEditingController(text: 'service'),
      notes = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    date.dispose();
    category.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New reminder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Reminder title')),
              const SizedBox(height: 10),
              TextField(controller: date, decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)'), keyboardType: TextInputType.datetime),
              const SizedBox(height: 10),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category: service / insurance / oil')),
              const SizedBox(height: 10),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date.text.trim())) {
                showMsg(context, 'Enter a title and date in YYYY-MM-DD format');
                return;
              }
              Navigator.pop(context, {
                'title': title.text.trim(),
                'due_date': date.text.trim(),
                'category': category.text.trim().isEmpty ? 'service' : category.text.trim(),
                'notes': notes.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class TravelPage extends StatefulWidget {
  const TravelPage({super.key});
  @override
  State<TravelPage> createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> {
  final from = TextEditingController(),
      to = TextEditingController(),
      distance = TextEditingController(),
      efficiency = TextEditingController(),
      price = TextEditingController();
  String? estimate;
  @override
  void dispose() {
    from.dispose();
    to.dispose();
    distance.dispose();
    efficiency.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> calculate() async {
    final km = double.tryParse(distance.text), eff = double.tryParse(efficiency.text), p = double.tryParse(price.text);
    if (km == null || eff == null || p == null || km <= 0 || eff <= 0 || p <= 0) {
      showMsg(context, 'Enter valid distance, efficiency and fuel price');
      return;
    }
    final litres = km / eff, cost = litres * p;
    setState(() => estimate = 'Distance: ${km.toStringAsFixed(1)} km\nFuel needed: ${litres.toStringAsFixed(2)} L\nEstimated fuel expense: ₹${cost.toStringAsFixed(2)}');
    try {
      await Api.request('POST', '/trips', body: {
        'origin': from.text.trim(),
        'destination': to.text.trim(),
        'distance_km': km,
        'fuel_efficiency': eff,
        'fuel_price': p,
      });
    } catch (_) {}
  }

  Future<void> maps() async {
    final actual = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeQueryComponent(from.text)}&destination=${Uri.encodeQueryComponent(to.text)}');
    if (!await launchUrl(actual, mode: LaunchMode.externalApplication) && mounted) showMsg(context, 'Could not open Maps');
  }

  @override
  Widget build(BuildContext context) => PageWrap(
        title: 'Trip planner',
        subtitle: 'Plan a route and estimate fuel costs.',
        child: Column(
          children: [
            TextField(controller: from, decoration: const InputDecoration(labelText: 'From — current location or place')),
            const SizedBox(height: 12),
            TextField(controller: to, decoration: const InputDecoration(labelText: 'To — destination')),
            const SizedBox(height: 12),
            primaryButton('Open route in Google Maps', maps, icon: Icons.map),
            const SizedBox(height: 12),
            TextField(controller: distance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Route distance (km)')),
            const SizedBox(height: 12),
            TextField(controller: efficiency, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Vehicle efficiency (km/litre)')),
            const SizedBox(height: 12),
            TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fuel price per litre (₹)')),
            const SizedBox(height: 14),
            primaryButton('Calculate fuel expense', calculate, icon: Icons.calculate),
            if (estimate != null) Padding(padding: const EdgeInsets.only(top: 14), child: actionCard(icon: Icons.receipt_long, title: 'Estimated trip cost', detail: estimate!)),
          ],
        ),
      );
}

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Emergency support')),
        body: PageWrap(
          title: 'Safety first',
          subtitle: 'Emergency tools and nearby assistance.',
          child: Column(
            children: [
              actionCard(
                icon: Icons.sos,
                title: 'SOS assistance',
                detail: 'The configured backend records a demo request only; it does not contact emergency services.',
                onTap: () => confirmSos(context),
              ),
              actionCard(
                icon: Icons.build_circle,
                title: 'Nearby mechanics',
                detail: 'Search repair shops using Google Maps.',
                onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=mechanic+near+me'), mode: LaunchMode.externalApplication),
              ),
              actionCard(
                icon: Icons.cloud_outlined,
                title: 'Weather alerts',
                detail: 'Open the official India Meteorological Department website.',
                onTap: () => launchUrl(Uri.parse('https://mausam.imd.gov.in/'), mode: LaunchMode.externalApplication),
              ),
              actionCard(
                icon: Icons.phone_in_talk,
                title: 'Emergency numbers — India',
                detail: 'Police: 112 · Ambulance: 108. Call official emergency services directly when needed.',
              ),
            ],
          ),
        ),
      );
}

Future<void> confirmSos(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Emergency SOS'),
      content: const Text('This project backend records a demo SOS only. It does not contact emergency services. For a real emergency in India, call 112.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Record demo SOS')),
      ],
    ),
  );
  if (yes != true) return;
  try {
    await Api.request('POST', '/emergency/sos', body: {'message': 'Emergency assistance requested from DrivePlus'});
    if (context.mounted) showMsg(context, 'Demo SOS recorded. No emergency service was contacted.');
  } catch (e) {
    if (context.mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
  }
}

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.onLogout});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) => PageWrap(
        title: 'Your profile',
        subtitle: 'Account and app preferences.',
        child: Column(
          children: [
            actionCard(icon: Icons.account_circle_outlined, title: 'Signed in as', detail: Api.email),
            actionCard(
              icon: Icons.dns_outlined,
              title: 'Backend Server Configuration',
              detail: 'Current: ${Api.baseUrl}\nTap to test connection or update server address.',
              onTap: () => showServerConfigDialog(context, onSaved: () => setState(() {})),
            ),
            actionCard(icon: Icons.info_outline, title: 'DrivePlus', detail: 'Flutter app · Vehicle companion'),
            primaryButton('Sign out', widget.onLogout, icon: Icons.logout),
          ],
        ),
      );
}

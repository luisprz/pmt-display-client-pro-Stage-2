import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Base URL where your JSON configs live in GitHub
/// Example final URL:
///   https://luisprz.github.io/pmt-signage/screens/gala-deli/1234-5678/1234-5678.json
const String kBaseConfigUrl =
    'https://luisprz.github.io/pmt-signage/screens/gala-deli';

/// Show debug overlay on top-left
const bool kShowDebugOverlay = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen, no system bars
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Keep the screen awake
  await WakelockPlus.enable();

  runApp(const PMTDisplayApp());
}

class PMTDisplayApp extends StatelessWidget {
  const PMTDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'ProMultiTech Display PRO',
      debugShowCheckedModeBanner: false,
      home: RootScreen(),
    );
  }
}

/// RootScreen is responsible for:
///  - Generating / loading the numeric Device ID
///  - Ensuring the Device ID is unique in GitHub (if created for the first time)
///  - Showing an error screen if there is no internet on first run
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  String _deviceId = '';
  bool _initialized = false;
  String? _initError; // error on first initialization (e.g. no internet)

  @override
  void initState() {
    super.initState();
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('deviceId');

    try {
      if (id == null || id.isEmpty) {
        // First time: we must generate a NEW numeric code
        // and verify with GitHub that it does NOT exist yet.
        id = await _generateUniqueDeviceIdOrThrow();
        await prefs.setString('deviceId', id);
      }

      setState(() {
        _deviceId = id!;
        _initialized = true;
        _initError = null;
      });
    } catch (e) {
      // If something goes wrong (no internet, timeouts, etc.),
      // we do NOT generate or store a code.
      setState(() {
        _initialized = true;
        _initError = e.toString();
      });
    }
  }

  /// Generates a numeric Device ID in the format "0000-0000"
  /// and checks GitHub to ensure there is NO JSON for that ID yet.
  ///
  /// If it cannot verify (no internet, timeout, etc.), it throws an exception.
  Future<String> _generateUniqueDeviceIdOrThrow() async {
    final random = Random.secure();
    const int maxAttempts = 8;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // 0 → 99,999,999 (8 digits)
      final number = random.nextInt(100000000);
      final raw = number.toString().padLeft(8, '0'); // always 8 digits

      // Format: "1234-5678"
      final candidate = '${raw.substring(0, 4)}-${raw.substring(4, 8)}';

      final uri = Uri.parse(
        '$kBaseConfigUrl/$candidate/$candidate.json',
      );

      try {
        final response = await http.get(uri).timeout(
          const Duration(seconds: 5),
        );

        if (response.statusCode == 404) {
          // ✅ No JSON yet for this ID → safe to use
          return candidate;
        }

        if (response.statusCode == 200) {
          // JSON already exists → this ID is in use, try another
          continue;
        }

        // Any other status (403, 500, etc.) is treated as an error.
        throw Exception(
          'Error checking GitHub (status: ${response.statusCode})',
        );
      } on SocketException catch (e) {
        // 🔴 No internet or network issue → do not generate ID
        throw Exception(
          'No internet connection to generate device code.\nDetails: $e',
        );
      } on TimeoutException catch (e) {
        throw Exception(
          'Timed out while verifying device code on GitHub.\nDetails: $e',
        );
      }
    }

    throw Exception(
      'Unable to generate a unique device code after several attempts.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If initialization failed (e.g. no internet on first run)
    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ProMultiTech Display',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to generate a device code.\n\n'
                  'Please make sure this Fire TV has internet access\n'
                  'and then relaunch the app.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (kShowDebugOverlay)
                  Text(
                    'Technical details:\n$_initError',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // All good: go to signage screen
    return SignageScreen(deviceId: _deviceId);
  }
}

/// SignageScreen:
///  - Loads the JSON config from GitHub based on the Device ID
///  - Supports "single" (one image) and "playlist"
///  - Caches last config in SharedPreferences for offline mode
///  - Shows a waiting screen if JSON does not exist yet
class SignageScreen extends StatefulWidget {
  final String deviceId;

  const SignageScreen({super.key, required this.deviceId});

  @override
  State<SignageScreen> createState() => _SignageScreenState();
}

class _SignageScreenState extends State<SignageScreen> {
  String _mode = 'single'; // 'single' or 'playlist'
  String? _currentImageUrl;
  List<String> _playlist = [];
  int _currentIndex = 0;

  int _rotationSeconds = 0; // for playlist
  int _refreshSeconds = 300; // for reloading JSON

  Timer? _rotationTimer;
  Timer? _refreshTimer;

  bool _loading = true;
  String? _errorMessage;
  bool _offline = false;
  bool _waitingAssignment = false;

  @override
  void initState() {
    super.initState();
    _loadConfigFromServer();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  String get _configUrl =>
      '$kBaseConfigUrl/${widget.deviceId}/${widget.deviceId}.json';

  Future<void> _loadConfigFromServer() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _waitingAssignment = false;
      _offline = false;
    });

    _rotationTimer?.cancel();
    _refreshTimer?.cancel();

    try {
      final uri = Uri.parse(
        '$_configUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        // No JSON yet for this deviceId
        setState(() {
          _waitingAssignment = true;
          _loading = false;
          _currentImageUrl = null;
          _playlist = [];
        });
        _scheduleRefreshRetry();
        return;
      }

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      final String mode = (data['mode'] as String?)?.toLowerCase() ?? 'single';
      final int refreshSeconds = (data['refresh_seconds'] as int?) ?? 300;

      String? singleUrl;
      List<String> playlist = [];
      int rotationSeconds = 0;

      if (mode == 'playlist') {
        final rawImages = data['images'];
        if (rawImages is List) {
          playlist = rawImages
              .whereType<String>()
              .where((url) => url.isNotEmpty)
              .toList();
        }
        rotationSeconds = (data['rotation_seconds'] as int?) ?? 15;
        if (playlist.isEmpty) {
          throw Exception("Empty playlist in 'playlist' mode.");
        }
      } else {
        singleUrl = data['image_url'] as String?;
        if (singleUrl == null || singleUrl.isEmpty) {
          throw Exception("Missing 'image_url' in 'single' mode.");
        }
      }

      // Save last good config for offline mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastConfigJson', response.body);

      setState(() {
        _mode = mode;
        _refreshSeconds = refreshSeconds;
        _rotationSeconds = rotationSeconds;
        _playlist = playlist;
        _currentIndex = 0;

        if (_mode == 'playlist') {
          _currentImageUrl = _playlist.first;
        } else {
          _currentImageUrl = singleUrl;
        }

        _loading = false;
        _offline = false;
        _waitingAssignment = false;
      });

      // Periodically reload JSON (refreshSeconds)
      _refreshTimer = Timer.periodic(
        Duration(seconds: _refreshSeconds),
        (_) => _loadConfigFromServer(),
      );

      // Playlist rotation
      if (_mode == 'playlist' &&
          _playlist.length > 1 &&
          _rotationSeconds > 0) {
        _rotationTimer = Timer.periodic(
          Duration(seconds: _rotationSeconds),
          (_) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % _playlist.length;
              _currentImageUrl = _playlist[_currentIndex];
            });
          },
        );
      }
    } on SocketException catch (e) {
      // Network issue → try offline mode
      await _loadLastConfigOffline();
      setState(() {
        _offline = true;
        _errorMessage = 'Offline: $e';
      });
      _scheduleRefreshRetry();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
      _scheduleRefreshRetry();
    }
  }

  Future<void> _loadLastConfigOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final lastJson = prefs.getString('lastConfigJson');
    if (lastJson == null) return;

    try {
      final data = json.decode(lastJson) as Map<String, dynamic>;
      final String mode = (data['mode'] as String?)?.toLowerCase() ?? 'single';

      String? singleUrl;
      List<String> playlist = [];
      int rotationSeconds = 0;
      final int refreshSeconds = (data['refresh_seconds'] as int?) ?? 300;

      if (mode == 'playlist') {
        final rawImages = data['images'];
        if (rawImages is List) {
          playlist = rawImages
              .whereType<String>()
              .where((url) => url.isNotEmpty)
              .toList();
        }
        rotationSeconds = (data['rotation_seconds'] as int?) ?? 15;
        if (playlist.isEmpty) return;
      } else {
        singleUrl = data['image_url'] as String?;
        if (singleUrl == null || singleUrl.isEmpty) return;
      }

      setState(() {
        _mode = mode;
        _refreshSeconds = refreshSeconds;
        _rotationSeconds = rotationSeconds;
        _playlist = playlist;
        _currentIndex = 0;

        if (_mode == 'playlist') {
          _currentImageUrl = _playlist.first;
        } else {
          _currentImageUrl = singleUrl;
        }

        _loading = false;
        _waitingAssignment = false;
      });

      if (_mode == 'playlist' &&
          _playlist.length > 1 &&
          _rotationSeconds > 0) {
        _rotationTimer = Timer.periodic(
          Duration(seconds: _rotationSeconds),
          (_) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % _playlist.length;
              _currentImageUrl = _playlist[_currentIndex];
            });
          },
        );
      }
    } catch (_) {
      // Ignore offline parsing errors
    }
  }

  void _scheduleRefreshRetry() {
    _refreshTimer = Timer(
      const Duration(seconds: 30),
      () => _loadConfigFromServer(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentImageUrl != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (remote or fallback)
          hasImage
              ? CachedNetworkImage(
                  imageUrl: _currentImageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/fallback.jpg',
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/fallback.jpg',
                  fit: BoxFit.cover,
                ),

          // "Waiting for assignment" screen when JSON does not exist
          if (_waitingAssignment)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ProMultiTech Display',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Device ID: ${widget.deviceId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Waiting for assignment...\n\n'
                      'Create the JSON file for this Device ID\n'
                      'in your GitHub config folder.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // *** NEW: Big "No internet" screen ***
          // Only if we are offline AND we don't have any remote image loaded
          if (_offline && _currentImageUrl == null && !_waitingAssignment)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ProMultiTech Display',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Device ID: ${widget.deviceId}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No internet connection detected.\n'
                      'Please check the network for this Fire TV.\n'
                      'The screen will update automatically\n'
                      'when the connection is restored.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Debug overlay (small box in the corner)
          if (kShowDebugOverlay)
            Positioned(
              left: 12,
              bottom: 12,
              child: Opacity(
                opacity: 0.8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Device: ${widget.deviceId}'),
                        Text('Mode: $_mode'),
                        Text('Loading: $_loading'),
                        Text('Offline: $_offline'),
                        Text('Waiting: $_waitingAssignment'),
                        Text('Current: ${_currentImageUrl ?? "fallback"}'),
                        Text('Rotation: $_rotationSeconds s'),
                        Text('Refresh: $_refreshSeconds s'),
                        Text('Config URL: $_configUrl'),
                        if (_errorMessage != null)
                          SizedBox(
                            width: 260,
                            child: Text(
                              'Error: $_errorMessage',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}

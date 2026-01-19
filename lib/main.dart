import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ar_flutter_plugin_updated/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_updated/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_updated/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_updated/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:ar_flutter_plugin_updated/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_updated/models/ar_hittest_result.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/shop/notifications_screen.dart';
import 'screens/shop/popular_products_screen.dart';
import 'screens/shop/new_arrivals_screen.dart';
import 'screens/shop/categories_screen.dart';
import 'screens/shop/shop_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart'; // Add this import if not already present


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Add this call
  readAndPrintRealtimeData();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3D Object Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const ShopShell(),
        '/cart': (context) => const ShopShell(initialIndex: 1),
        '/orders': (context) => const ShopShell(initialIndex: 2),
        '/profile': (context) => const ShopShell(initialIndex: 3),
        '/notifications': (context) => const NotificationsScreen(),
        '/popular-products': (context) => const PopularProductsScreen(),
        '/new-arrivals': (context) => const NewArrivalsScreen(),
        '/categories': (context) => const CategoriesScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// ignore: unused_element
Future<void> _loadUserData() async {
  // Your Firebase calls
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // _loadUserData();
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 200, // Adjust size as needed
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Discover Beautiful Wooden\nFurniture Designs',
      description: 'Explore furniture that blends style and comfort.',
      imagePath: 'assets/images/onboarding1.png',
    ),
    OnboardingPage(
      title: 'Crafted with Care, Built\nto Last a Lifetime',
      description: 'Made from premium, sustainable wood by\nskilled artisans.',
      imagePath: 'assets/images/onboarding2.png',
    ),
    OnboardingPage(
      title: 'Seamless Shopping\nExperience',
      description: 'Browse, customize, and order with\nease.',
      imagePath: 'assets/images/onboarding3.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _navigateToDashboard,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 16),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildPageIndicator(index),
                ),
              ),
            ),

            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDB022),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: Center(
              child: Image.asset(page.imagePath, fit: BoxFit.contain),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    bool isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFDB022) : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

class ThreeDViewerDashboard extends StatefulWidget {
  const ThreeDViewerDashboard({super.key});

  @override
  State<ThreeDViewerDashboard> createState() => _ThreeDViewerDashboardState();
}

class _ThreeDViewerDashboardState extends State<ThreeDViewerDashboard> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  ARNode? astronautNode;

  @override
  void dispose() {
    super.dispose();
    arSessionManager?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AR Astronaut Viewer'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Integrated AR Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    astronautNode == null
                        ? 'Looking for surfaces... Model will appear automatically.'
                        : 'Model placed! Move around to view.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  if (astronautNode == null)
                    ElevatedButton.icon(
                      onPressed: _addModel,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Try Adding Manually'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handleTaps: true,
    );
    this.arObjectManager!.onInitialize();

    // Set up plane tap handler for manual placement
    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTapped;

    // Automatically load the model after a longer delay
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && astronautNode == null) {
        _addModel();
      }
    });
  }

  void onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    if (astronautNode != null) return; // Already placed

    var singleHitTestResult = hitTestResults.firstOrNull;
    if (singleHitTestResult != null) {
      var newAnchor = ARPlaneAnchor(
        transformation: singleHitTestResult.worldTransform,
      );
      bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

      if (didAddAnchor == true) {
        _addModelAtAnchor(newAnchor);
      }
    }
  }

  Future<void> _addModelAtAnchor(ARPlaneAnchor anchor) async {
    if (astronautNode != null) return;

    try {
      var newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: 'Astronaut.glb',
        scale: vector.Vector3(0.2, 0.2, 0.2),
        position: vector.Vector3(0, 0, 0), // Position relative to anchor
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      bool? didAddNode = await arObjectManager!.addNode(
        newNode,
        planeAnchor: anchor,
      );

      if (didAddNode == true && mounted) {
        setState(() {
          astronautNode = newNode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model placed on surface!')),
        );
      }
    } catch (e) {
      debugPrint('Error adding model at anchor: $e');
    }
  }

  Future<void> _addModel() async {
    if (astronautNode != null) return;

    // Verify asset exists from Dart side
    try {
      await rootBundle.load('assets/models/Astronaut.glb');
      debugPrint(
        'Asset assets/models/Astronaut.glb loaded successfully from rootBundle',
      );
    } catch (e) {
      debugPrint('Error loading asset from rootBundle: $e');
      return;
    }

    bool? didAddNode;
    ARNode? newNode;
    try {
      final Directory docDir = await getApplicationDocumentsDirectory();
      final String localPath = '${docDir.path}/Astronaut.glb';
      final File localFile = File(localPath);

      if (!await localFile.exists()) {
        debugPrint('Copying asset to local storage...');
        final ByteData data = await rootBundle.load(
          'assets/models/Astronaut.glb',
        );
        final List<int> bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await localFile.writeAsBytes(bytes);
        debugPrint('Asset copied to: $localPath');
      } else {
        debugPrint('Asset already exists at: $localPath');
      }

      // For fileSystemAppFolderGLB, use just the filename
      var nodePath = 'Astronaut.glb';
      newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: nodePath,
        scale: vector.Vector3(1.0, 1.0, 1.0), // Much larger scale
        position: vector.Vector3(0, 0, -2.0), // 2 meters in front
        rotation: vector.Vector4(1, 0, 0, 0),
      );

      debugPrint('Attempting to add node from local storage: $nodePath');
      didAddNode = await arObjectManager!.addNode(newNode);
      debugPrint('ARNode add result (local storage): $didAddNode');

      if (didAddNode != true) {
        nodePath = 'assets/models/Astronaut.glb';
        newNode = ARNode(
          type: NodeType.localGLTF2,
          uri: nodePath,
          scale: vector.Vector3(0.5, 0.5, 0.5),
          position: vector.Vector3(0, 0, -1.5),
          rotation: vector.Vector4(1, 0, 0, 0),
        );
        didAddNode = await arObjectManager!.addNode(newNode);
        debugPrint('ARNode add result (fallback assets): $didAddNode');
      }
    } catch (e) {
      debugPrint('Exception while adding node: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding model: $e')));
      }
    }

    if (didAddNode == true) {
      if (mounted) {
        setState(() {
          astronautNode = newNode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model loaded successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load model - check logs.')),
        );
      }
    }
  }
}

// Add this function to read and print realtime database data
void readAndPrintRealtimeData() {
  const String path = '/'; // Replace with your actual database path, e.g., '/users'
  print('Realtime data:');
  FirebaseService.streamData(path).listen((data) {
    print('Realtime data: $data');
  }, onError: (error) {
    print('Error reading realtime data: $error');
  });
}

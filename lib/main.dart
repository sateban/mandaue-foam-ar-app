import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'screens/onboarding/splash_screen_v1.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/walkthrough_screen.dart';
import 'screens/auth/lets_you_in_screen.dart';
import 'screens/auth/fill_profile_screen.dart';
import 'screens/auth/create_pin_screen.dart';
import 'screens/auth/set_fingerprint_screen.dart';
import 'screens/auth/account_setup_success_screen.dart';
import 'screens/auth/password_reset_success_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/shop/checkout/shipping_address_screen.dart';
import 'screens/shop/checkout/address_list_screen.dart';
import 'screens/shop/checkout/add_address_screen.dart';
import 'screens/shop/checkout/payment_method_screen.dart';
import 'screens/shop/checkout/payment_success_screen.dart';
import 'screens/shop/checkout/order_receipt_screen.dart';
import 'screens/shop/profile/edit_profile_screen.dart';
import 'screens/shop/profile/coupons_screen.dart';
import 'screens/shop/wishlist_screen.dart';
import 'screens/shop/notifications_screen.dart';
import 'screens/shop/popular_products_screen.dart';
import 'screens/shop/all_products_screen.dart';
import 'screens/shop/new_arrivals_screen.dart';
import 'screens/shop/categories_screen.dart';
import 'screens/shop/item_category_screen.dart';
import 'screens/shop/shop_shell.dart';
import 'screens/shop/search_products_screen.dart';
import 'screens/shop/track_order_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/filebase_service.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'models/order.dart';
import 'package:provider/provider.dart';
import 'utils/color_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('DEBUG: Initializing Firebase...');
    print('DEBUG: Current Platform: ${defaultTargetPlatform.toString()}');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('DEBUG: Firebase initialized successfully');
    print('DEBUG: Firebase Auth instance: ${FirebaseAuth.instance}');
  } catch (e) {
    print('ERROR: Firebase initialization failed: $e');
    print(
      'ERROR: This may indicate missing google-services.json or configuration issues',
    );
  }

  try {
    print('DEBUG: Initializing Filebase service...');
    await FilebaseService.initialize();
  } catch (e) {
    print('ERROR: Filebase initialization failed: $e');
  }

  try {
    FirebaseService.streamData('colors').listen(
      (data) {
        if (data.isEmpty) {
          print('📦 Color stream: received empty map, skipping update');
          return;
        }

        try {
          final mapped = <String, String>{};
          data.forEach((key, value) {
            if (key == null || value == null) return;
            mapped[key.toString()] = value.toString();
          });

          if (mapped.isNotEmpty) {
            ColorUtils.updateColorMap(mapped);
          } else {
            print('📦 Color stream: no valid entries after mapping');
          }
        } catch (e) {
          print('⚠️ Error processing color stream data: $e');
        }
      },
      onError: (error) {
        print('⚠️ Error in color stream: $error');
      },
    );
  } catch (e) {
    print('⚠️ Failed to start color stream listener: $e');
  }

  runApp(const MyApp());
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('DEBUG: Checking authentication state...');
          return const SplashScreenV1();
        }

        if (snapshot.hasError) {
          print('DEBUG: Authentication error: ${snapshot.error}');
          return const SplashScreenV1();
        }

        if (snapshot.hasData && snapshot.data != null) {
          print('DEBUG: User authenticated, navigating to home');
          return const ShopShell();
        }

        print('DEBUG: No user authenticated, showing splash screen');
        return const SplashScreenV1();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(
          create: (context) => ProductProvider()..loadProducts(),
        ),
        ChangeNotifierProxyProvider<UserProvider, CartProvider>(
          create: (context) => CartProvider(),
          update: (context, userProvider, cartProvider) =>
              cartProvider!..updateUser(userProvider),
        ),
      ],
      child: MaterialApp(
        title: 'Mandaue Foam',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6200EE),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
            ],
          );
        },
        home: const AuthenticationWrapper(),
        onGenerateRoute: (settings) {
          if (settings.name == '/track-order') {
            final order = settings.arguments as Order;
            return MaterialPageRoute(
              builder: (context) => TrackOrderScreen(order: order),
            );
          }
          return null;
        },
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/walkthrough': (context) => const WalkthroughScreen(),

          '/lets-you-in': (context) => const LetsYouInScreen(),
          '/sign-in': (context) => const SignInScreen(),
          '/sign-up': (context) => const SignUpScreen(),
          '/fill-profile': (context) => const FillProfileScreen(),
          '/create-pin': (context) => const CreatePinScreen(),
          '/set-fingerprint': (context) => const SetFingerprintScreen(),
          '/account-setup-success': (context) =>
              const AccountSetupSuccessScreenStateful(),
          '/password-reset-success': (context) =>
              const PasswordResetSuccessScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),

          '/home': (context) => const ShopShell(),
          '/cart': (context) => const ShopShell(initialIndex: 1),
          '/orders': (context) => const ShopShell(initialIndex: 2),
          '/profile': (context) => const ShopShell(initialIndex: 3),

          '/notifications': (context) => const NotificationsScreen(),
          '/popular-products': (context) => const PopularProductsScreen(),
          '/all-products': (context) => const AllProductsScreen(),
          '/new-arrivals': (context) => const NewArrivalsScreen(),
          '/categories': (context) => const CategoriesScreen(),
          '/item-category': (context) {
            final categoryName =
                ModalRoute.of(context)?.settings.arguments as String?;
            return ItemCategoryScreen(categoryName: categoryName ?? 'Products');
          },
          '/search-products': (context) => const SearchProductsScreen(),

          '/shipping-address': (context) => const ShippingAddressScreen(),
          '/address-list': (context) => const AddressListScreen(),
          '/add-address': (context) => const AddAddressScreen(),
          '/payment-method': (context) => const PaymentMethodScreen(),
          '/payment-success': (context) => const PaymentSuccessScreen(),
          '/order-receipt': (context) => const OrderReceiptScreen(),

          '/edit-profile': (context) => const EditProfileScreen(),
          '/coupons': (context) => const CouponsScreen(),
          '/wishlist': (context) => const WishlistScreen(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

Future<void> _loadUserData() async {
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
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
          width: 200,
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
          Expanded(
            flex: 3,
            child: Center(
              child: Image.asset(page.imagePath, fit: BoxFit.contain),
            ),
          ),

          const SizedBox(height: 40),

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

void readAndPrintRealtimeData() {
  const String path = '/'; 
  FirebaseService.streamData(path).listen(
    (data) {
      print('Realtime data: $data');
    },
    onError: (error) {
      print('Error reading realtime data: $error');
    },
  );
}

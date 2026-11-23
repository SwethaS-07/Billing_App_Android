import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/billing/presentation/pages/home_page.dart';
import '../../features/billing/presentation/pages/billing_page.dart';
import '../../features/billing/presentation/pages/customer_profile_page.dart';
import '../../features/billing/presentation/pages/history_page.dart';
import '../../features/product/presentation/pages/product_list_page.dart';
import '../../features/product/presentation/pages/add_product_page.dart';
import '../../features/product/presentation/pages/edit_product_page.dart';
import '../../features/shop/presentation/pages/shop_details_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/billing/presentation/pages/scanner_page.dart';
import '../../features/billing/presentation/pages/checkout_page.dart';
import '../../features/billing/presentation/pages/customer_info_page.dart';
import '../../features/product/domain/entities/product.dart';

class BottomNavShell extends StatelessWidget {
  final Widget child;
  final String currentLocation;
  const BottomNavShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  final List<String> _routes = const [
    '/',
    '/products',
    '/customers',
    '/history',
    '/settings',
  ];

  void _onItemTapped(BuildContext context, int index) {
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _routes.contains(currentLocation)
        ? _routes.indexOf(currentLocation)
        : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(context, index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Products',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return BottomNavShell(currentLocation: state.uri.path, child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductListPage(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddProductPage(),
            ),
            GoRoute(
              path: 'edit/:id',
              builder: (context, state) {
                final product = state.extra as Product?;
                if (product == null) {
                  return const ProductListPage();
                }
                return EditProductPage(product: product);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomerProfilePage(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/shop',
          builder: (context, state) => const ShopDetailsPage(),
        ),
      ],
    ),
    // Full-screen billing flow (no bottom navigation bar).
    GoRoute(path: '/billing', builder: (context, state) => const BillingPage()),
    GoRoute(
      path: '/customer-info',
      builder: (context, state) => const CustomerInfoPage(),
    ),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutPage(),
    ),
    GoRoute(path: '/scanner', builder: (context, state) => const ScannerPage()),
  ],
);

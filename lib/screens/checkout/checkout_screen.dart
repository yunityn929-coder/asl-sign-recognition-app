import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/checkout_data.dart';

// S-15 — Session Checkout
class CheckoutScreen extends ConsumerWidget {
  final CheckoutData checkoutData;
  const CheckoutScreen({required this.checkoutData, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Session Checkout — TODO')),
    );
  }
}

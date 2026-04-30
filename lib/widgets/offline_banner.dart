import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final bool offline;

  const OfflineBanner({super.key, required this.offline});

  @override
  Widget build(BuildContext context) {
    if (!offline) return const SizedBox();

    return Container(
      width: double.infinity,
      color: Colors.orange,
      padding: const EdgeInsets.all(6),
      child: const Text(
        "Offline Mode",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../home/main_shell.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String guestEmail;

  const BookingSuccessScreen({
    super.key,
    required this.guestEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [

              const SizedBox(height: 60),

              // Stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircleAvatar(radius: 14, child: Text("1")),
                  Expanded(child: Divider()),
                  CircleAvatar(radius: 14, child: Text("2")),
                  Expanded(child: Divider()),
                  CircleAvatar(radius: 14, child: Text("3")),
                ],
              ),

              const SizedBox(height: 60),

              // Check icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(.15),
                ),
                child: const Icon(
                  Icons.check,
                  size: 50,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "You're all set!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Start getting ready for your stay.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 40),

              Text(
                "We've sent your itinerary to\n$guestEmail",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),

              const Spacer(),

              // Go home button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainShell(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    "Go back home",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24)
            ],
          ),
        ),
      ),
    );
  }
}
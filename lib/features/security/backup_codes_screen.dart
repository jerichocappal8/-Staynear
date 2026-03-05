import 'package:flutter/material.dart';

class BackupCodesScreen extends StatelessWidget {

  final List<String> codes;

  const BackupCodesScreen({super.key, required this.codes});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Backup Codes"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [

            const Text(
              "Save these backup codes.\nYou can use them if you lose access to Google Authenticator.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),

                itemCount: codes.length,

                itemBuilder: (_, i) {

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Center(
                      child: Text(
                        codes[i],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );

                },
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {

                // Close BackupCodesScreen
                Navigator.pop(context);

                // Close Verify2FAScreen
                Navigator.pop(context);

                // Close Setup2FAScreen
                Navigator.pop(context);

              },
              child: const Text("I Saved Them"),
            ),

          ],
        ),
      ),
    );
  }
}
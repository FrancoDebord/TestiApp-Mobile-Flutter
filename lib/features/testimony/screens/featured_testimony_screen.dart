import 'package:flutter/material.dart';

class FeaturedTestimonyScreen extends StatelessWidget {
  const FeaturedTestimonyScreen({required this.testimonyId, super.key});
  final String testimonyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À la une')),
      body: Center(child: Text('Témoignage à la une: $testimonyId')),
    );
  }
}

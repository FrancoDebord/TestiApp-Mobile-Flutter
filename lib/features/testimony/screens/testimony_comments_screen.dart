import 'package:flutter/material.dart';

class TestimonyCommentsScreen extends StatelessWidget {
  const TestimonyCommentsScreen({required this.testimonyId, super.key});
  final String testimonyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commentaires')),
      body: Center(child: Text('Commentaires pour: $testimonyId')),
    );
  }
}

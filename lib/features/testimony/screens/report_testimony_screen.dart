import 'package:flutter/material.dart';

class ReportTestimonyScreen extends StatelessWidget {
  const ReportTestimonyScreen({required this.testimonyId, super.key});
  final String testimonyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler')),
      body: Center(child: Text('Signaler témoignage: $testimonyId')),
    );
  }
}

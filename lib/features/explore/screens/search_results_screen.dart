import 'package:flutter/material.dart';

class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({required this.query, super.key});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Résultats : $query')),
      body: const Center(child: Text('Résultats de recherche')),
    );
  }
}

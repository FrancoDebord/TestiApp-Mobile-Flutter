import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({required this.query, super.key});
  final String query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.searchResults} : $query')),
      body: Center(child: Text(l10n.searchResultsBody)),
    );
  }
}

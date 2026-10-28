// Erreur due à l'absence de réseau (aucune réponse du serveur) : l'action peut
// être gardée sur le téléphone et rejouée plus tard (file hors connexion).

import 'dart:async' show TimeoutException;
import 'dart:io' show HttpException, SocketException;

import 'package:dio/dio.dart';

/// Erreur d'un dépôt qui sait si elle vient d'une coupure réseau.
abstract interface class OfflineAwareFailure {
  bool get offline;
}

/// Vrai si [error] signifie « le serveur n'a pas pu être joint » (pas de réponse),
/// faux pour un refus du serveur (4xx, 5xx) ou une erreur de l'application.
bool isNetworkFailure(Object error) {
  if (error is OfflineAwareFailure) return error.offline;
  if (error is DioException) {
    if (error.response != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.unknown => true,
      _ => false,
    };
  }
  return error is SocketException || error is TimeoutException || error is HttpException;
}

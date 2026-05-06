abstract class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class AuthException extends AppException {
  const AuthException(super.message);
}

class FirestoreException extends AppException {
  const FirestoreException(super.message);
}

class FirestorePermissionException extends FirestoreException {
  const FirestorePermissionException(super.message);
}

class RecognitionException extends AppException {
  const RecognitionException(super.message);
}

class NotificationException extends AppException {
  const NotificationException(super.message);
}

class KeyService {
  /// Validate and import a private key from a pasted PEM string.
  /// Returns the trimmed PEM if valid, null otherwise.
  String? importKeyFromString(String pem) {
    final trimmed = pem.trim();
    if (trimmed.startsWith('-----BEGIN') && trimmed.contains('PRIVATE KEY')) {
      return trimmed;
    }
    return null;
  }

  /// Check if a PEM key appears to be encrypted.
  bool isEncrypted(String pem) {
    return pem.contains('ENCRYPTED');
  }
}

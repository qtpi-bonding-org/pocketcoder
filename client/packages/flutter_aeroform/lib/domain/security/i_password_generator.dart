/// Abstract interface for secure password generation
abstract class IPasswordGenerator {
  /// Generates a secure password with:
  /// - Exactly 20 characters
  /// - At least 4 uppercase letters
  /// - At least 4 lowercase letters
  /// - At least 4 digits
  /// - At least 4 special characters from !@#$%^&*
  Future<String> generatePassword();

  /// Generates admin password
  Future<String> generateAdminPassword();

  /// Generates root password
  Future<String> generateRootPassword();
}
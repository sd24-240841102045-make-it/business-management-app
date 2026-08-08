import 'package:encrypt/encrypt.dart';

class EncryptionService {
  // 32-character fixed string for AES-256 (256 bits).
  // In a real production app, this should be fetched from .env or flutter_secure_storage.
  static const String _secretKeyString = 'BMS_Secure_Encryption_Key_32_Chr'; 
  
  static final Key _key = Key.fromUtf8(_secretKeyString);
  // Using a static IV for simplicity, though dynamic IVs stored with the cipher are better practice.
  static final IV _iv = IV.fromLength(16); 
  
  static final Encrypter _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      return plainText;
    }
  }

  static String decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return encryptedBase64;
    try {
      final encrypted = Encrypted.fromBase64(encryptedBase64);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      // If decryption fails (e.g., an old unencrypted message), return original
      return encryptedBase64;
    }
  }
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabasePublishableKey {
    return dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
  }

  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
  }
}

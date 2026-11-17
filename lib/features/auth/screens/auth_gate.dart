import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/screens/home_screen.dart';
import '../../profile/screens/profile_setup_screen.dart';
import '../../profile/services/profile_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Authentication error: ${snapshot.error}',
              ),
            ),
          );
        }

        final session =
            snapshot.data?.session ?? supabase.auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        return const _ProfileGate();
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate();

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  final ProfileService _profileService = ProfileService();

  bool _loading = true;
  bool _profileComplete = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();

     final complete = profile != null &&
    (profile.firstName?.trim().isNotEmpty ?? false) &&
    (profile.lastName?.trim().isNotEmpty ?? false) &&
    (profile.studentNumber?.trim().isNotEmpty ?? false) &&
    (profile.city?.trim().isNotEmpty ?? false) &&
    (profile.campus?.trim().isNotEmpty ?? false) &&
    (profile.branch?.trim().isNotEmpty ?? false) &&
    profile.studyYear != null &&
    (profile.targetRole?.trim().isNotEmpty ?? false);

      if (!mounted) return;

      setState(() {
        _profileComplete = complete;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _profileComplete = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_profileComplete) {
      return const ProfileSetupScreen();
    }

    return const HomeScreen();
  }
}

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveLocationService {
  final SupabaseClient _client = Supabase.instance.client;

  StreamSubscription<Position>? _positionSubscription;

  bool get isSharing => _positionSubscription != null;

  Future<void> _checkLocationPermission() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Active la localisation GPS de ton téléphone.');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permission GPS refusée.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Autorisation GPS bloquée. Active-la dans les paramètres du téléphone.',
      );
    }
  }

  Future<void> startSharing({
    required String visibility,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    if (visibility != 'all' && visibility != 'friends') {
      throw Exception('Paramètre de visibilité invalide.');
    }

    await _checkLocationPermission();

    await _client.from('profiles').update({
      'live_location_enabled': true,
      'live_location_visibility': visibility,
    }).eq('id', user.id);

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    await _savePosition(user.id, position);

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        _savePosition(user.id, position).catchError((error) {
          // Une erreur d'enregistrement ne doit pas arrêter le flux GPS.
        });
      },
    );
  }

  Future<void> _savePosition(
    String userId,
    Position position,
  ) async {
    await _client.from('student_live_locations').upsert(
      {
        'student_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'student_id',
    );
  }

  Future<void> updateVisibility(String visibility) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    if (visibility != 'all' && visibility != 'friends') {
      throw Exception('Paramètre de visibilité invalide.');
    }

    await _client.from('profiles').update({
      'live_location_visibility': visibility,
    }).eq('id', user.id);
  }

  Future<void> stopSharing() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    await _client.from('profiles').update({
      'live_location_enabled': false,
    }).eq('id', user.id);

    await _client
        .from('student_live_locations')
        .delete()
        .eq('student_id', user.id);
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/live_location_service.dart';

class LiveLocationSettingsScreen extends StatefulWidget {
  const LiveLocationSettingsScreen({super.key});

  @override
  State<LiveLocationSettingsScreen> createState() =>
      _LiveLocationSettingsScreenState();
}

class _LiveLocationSettingsScreenState
    extends State<LiveLocationSettingsScreen> {
  final LiveLocationService _locationService = LiveLocationService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isProcessing = false;

  String _visibility = 'friends';
  String? _errorMessage;

  static const Color primaryGreen = Color(0xFF16845B);
  static const Color darkGreen = Color(0xFF105C40);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Utilisateur non connecté.');
      }

      final profile = await _supabase
          .from('profiles')
          .select('live_location_enabled, live_location_visibility')
          .eq('id', user.id)
          .single();

      final enabled = profile['live_location_enabled'] == true;

      final visibility =
          profile['live_location_visibility'] as String? ?? 'friends';

      if (!mounted) return;

      setState(() {
        _isEnabled = enabled;
        _visibility = visibility;
        _isLoading = false;
      });

      if (enabled) {
        await _locationService.startSharing(
          visibility: visibility,
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleSharing() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (_isEnabled) {
        await _locationService.stopSharing();

        if (!mounted) return;

        setState(() {
          _isEnabled = false;
        });
      } else {
        await _locationService.startSharing(
          visibility: _visibility,
        );

        if (!mounted) return;

        setState(() {
          _isEnabled = true;
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _changeVisibility(String value) async {
    if (_isProcessing || value == _visibility) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await _locationService.updateVisibility(value);

      if (!mounted) return;

      setState(() {
        _visibility = value;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Widget _buildVisibilityOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final selected = _visibility == value;

    return InkWell(
      onTap: _isProcessing
          ? null
          : () => _changeVisibility(value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? primaryGreen
                : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? primaryGreen
                  : Colors.grey.shade600,
              size: 25,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? primaryGreen
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text(
          'Partage de position',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryGreen,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: primaryGreen,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Position GPS en direct',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Partage ta position avec les étudiants autorisés.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isEnabled
                              ? const Color(0xFFE8F5EE)
                              : const Color(0xFFF1F2F3),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isEnabled
                                  ? Icons.location_searching
                                  : Icons.location_disabled,
                              color: _isEnabled
                                  ? primaryGreen
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isEnabled
                                    ? 'Le partage est activé'
                                    : 'Le partage est désactivé',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isEnabled
                                      ? darkGreen
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : _toggleSharing,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isEnabled
                                      ? Icons.stop_circle_outlined
                                      : Icons.my_location,
                                ),
                          label: Text(
                            _isEnabled
                                ? 'Arrêter le partage'
                                : 'Activer le partage GPS',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isEnabled
                                ? Colors.red.shade600
                                : primaryGreen,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Qui peut voir ma position ?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 12),
                _buildVisibilityOption(
                  value: 'all',
                  title: 'Tous les étudiants EMSI',
                  description:
                      'Tous les étudiants connectés peuvent voir ta position.',
                  icon: Icons.groups,
                ),
                _buildVisibilityOption(
                  value: 'friends',
                  title: 'Mes amis uniquement',
                  description:
                      'Seuls tes amis acceptés peuvent voir ta position.',
                  icon: Icons.people_alt,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Confidentialité : le partage GPS est désactivé par défaut. '
                  'Tu peux l’arrêter à tout moment.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }
}
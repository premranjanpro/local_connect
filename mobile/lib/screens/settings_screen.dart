import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _taskSoundAlerts = true;
  bool _voiceTtsGuidance = true;
  bool _autoGpsTracking = true;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings & Preferences',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('NOTIFICATIONS & ALERTS'),
            _cardContainer([
              _switchTile(
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFF38BDF8),
                title: 'Push Notifications',
                subtitle: 'Receive real-time order & task dispatch updates',
                value: _pushNotifications,
                onChanged: (v) => setState(() => _pushNotifications = v),
              ),
              const Divider(height: 1, color: Colors.white10),
              _switchTile(
                icon: Icons.volume_up_rounded,
                color: const Color(0xFF10B981),
                title: 'High-Priority Sound Alerts',
                subtitle: 'Play ringtone on incoming task or VoIP call',
                value: _taskSoundAlerts,
                onChanged: (v) => setState(() => _taskSoundAlerts = v),
              ),
              const Divider(height: 1, color: Colors.white10),
              _switchTile(
                icon: Icons.record_voice_over_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Voice Guidance (TTS)',
                subtitle: 'Audio announcement for pickup, drops, and stops',
                value: _voiceTtsGuidance,
                onChanged: (v) => setState(() => _voiceTtsGuidance = v),
              ),
            ]),
            const SizedBox(height: 20),

            _sectionLabel('DEVICE & LOCATION'),
            _cardContainer([
              _switchTile(
                icon: Icons.gps_fixed_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Live MQTT GPS Telemetry',
                subtitle: 'Transmit background location during active delivery',
                value: _autoGpsTracking,
                onChanged: (v) => setState(() => _autoGpsTracking = v),
              ),
            ]),
            const SizedBox(height: 20),

            _sectionLabel('LANGUAGE & REGIONAL'),
            _cardContainer([
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF60A5FA), size: 20),
                ),
                title: const Text('App Language', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English')),
                      DropdownMenuItem(value: 'Hindi', child: Text('हिन्दी (Hindi)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLanguage = v);
                    },
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _sectionLabel('ABOUT'),
            _cardContainer([
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                title: const Text('Local Connect Platform', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Version 1.0.0 (Release Build)', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
      ),
    );
  }

  Widget _cardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      value: value,
      activeThumbColor: color,
      onChanged: onChanged,
    );
  }
}

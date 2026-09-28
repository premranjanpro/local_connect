import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings & Preferences',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('APPEARANCE & THEME'),
            _cardContainer(cardBg, borderColor, [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Display Theme',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Choose your visual appearance',
                              style: TextStyle(color: subTextColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _themeOptionCard(
                            title: 'Dark',
                            subtitle: 'OLED Slate',
                            icon: Icons.dark_mode_rounded,
                            isSelected: themeProvider.mode == ThemeMode.dark,
                            activeColor: const Color(0xFF38BDF8),
                            textColor: textColor,
                            onTap: () => themeProvider.setDark(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _themeOptionCard(
                            title: 'Light',
                            subtitle: 'Clean Crisp',
                            icon: Icons.light_mode_rounded,
                            isSelected: themeProvider.mode == ThemeMode.light,
                            activeColor: const Color(0xFFF59E0B),
                            textColor: textColor,
                            onTap: () => themeProvider.setLight(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _themeOptionCard(
                            title: 'System',
                            subtitle: 'Auto Follow',
                            icon: Icons.settings_brightness_rounded,
                            isSelected: themeProvider.mode == ThemeMode.system,
                            activeColor: const Color(0xFF10B981),
                            textColor: textColor,
                            onTap: () => themeProvider.setSystem(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _sectionLabel('NOTIFICATIONS & ALERTS'),
            _cardContainer(cardBg, borderColor, [
              _switchTile(
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFF38BDF8),
                title: 'Push Notifications',
                subtitle: 'Receive real-time order & task dispatch updates',
                value: _pushNotifications,
                textColor: textColor,
                subTextColor: subTextColor,
                onChanged: (v) => setState(() => _pushNotifications = v),
              ),
              Divider(height: 1, color: borderColor),
              _switchTile(
                icon: Icons.volume_up_rounded,
                color: const Color(0xFF10B981),
                title: 'High-Priority Sound Alerts',
                subtitle: 'Play ringtone on incoming task or VoIP call',
                value: _taskSoundAlerts,
                textColor: textColor,
                subTextColor: subTextColor,
                onChanged: (v) => setState(() => _taskSoundAlerts = v),
              ),
              Divider(height: 1, color: borderColor),
              _switchTile(
                icon: Icons.record_voice_over_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Voice Guidance (TTS)',
                subtitle: 'Audio announcement for pickup, drops, and stops',
                value: _voiceTtsGuidance,
                textColor: textColor,
                subTextColor: subTextColor,
                onChanged: (v) => setState(() => _voiceTtsGuidance = v),
              ),
            ]),
            const SizedBox(height: 20),

            _sectionLabel('DEVICE & LOCATION'),
            _cardContainer(cardBg, borderColor, [
              _switchTile(
                icon: Icons.gps_fixed_rounded,
                color: const Color(0xFF8B5CF6),
                title: 'Live MQTT GPS Telemetry',
                subtitle: 'Transmit background location during active delivery',
                value: _autoGpsTracking,
                textColor: textColor,
                subTextColor: subTextColor,
                onChanged: (v) => setState(() => _autoGpsTracking = v),
              ),
            ]),
            const SizedBox(height: 20),

            _sectionLabel('LANGUAGE & REGIONAL'),
            _cardContainer(cardBg, borderColor, [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded, color: Color(0xFF60A5FA), size: 20),
                ),
                title: Text('App Language', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: cardBg,
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
            _cardContainer(cardBg, borderColor, [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                title: Text('Local Connect Platform', style: TextStyle(color: textColor, fontSize: 14)),
                subtitle: Text('Version 1.0.0 (Release Build)', style: TextStyle(color: subTextColor, fontSize: 12)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _themeOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? activeColor : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? activeColor.withValues(alpha: 0.8) : Colors.grey,
                fontSize: 9,
              ),
            ),
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

  Widget _cardContainer(Color bg, Color border, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
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
    required Color textColor,
    required Color subTextColor,
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
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 11)),
      value: value,
      activeThumbColor: color,
      onChanged: onChanged,
    );
  }
}


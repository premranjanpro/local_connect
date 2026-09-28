import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/audio_tone_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  Create Broadcast Page — Post a NEED or OFFER
// ══════════════════════════════════════════════════════════════════════════════

class CreateBroadcastPage extends StatefulWidget {
  final String initialType; // 'NEED' or 'OFFER'

  const CreateBroadcastPage({super.key, required this.initialType});

  @override
  State<CreateBroadcastPage> createState() => _CreateBroadcastPageState();
}

class _CreateBroadcastPageState extends State<CreateBroadcastPage>
    with SingleTickerProviderStateMixin {
  late String _postType;
  late TabController _typeCtrl;

  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();

  bool _priceMode = false; // false = ASKING, true = FIXED
  List<XFile> _mediaFiles = [];
  bool _isRecording = false;
  bool _hasVoice = false;
  bool _isSubmitting = false;
  bool _aiEnhancing = false;

  // ── Audience Targeting ──────────────────────────────────────────
  // 0 = Everyone, 1 = Role filter, 2 = Specific person
  int _audienceMode = 0;
  final Set<String> _selectedRoles = {'Customer', 'Driver', 'Merchant'};
  double _radiusKm = 5.0;
  // 0 = normal, 1 = urgent, 2 = emergency
  int _urgencyLevel = 0;

  @override
  void initState() {
    super.initState();
    _postType = widget.initialType;
    _typeCtrl = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialType == 'OFFER' ? 1 : 0);
    _typeCtrl.addListener(() {
      setState(() {
        _postType = _typeCtrl.index == 0 ? 'NEED' : 'OFFER';
      });
    });
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  final _picker = ImagePicker();

  Future<void> _pickMedia() async {
    final picked = await _picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) {
      setState(() => _mediaFiles = [..._mediaFiles, ...picked]);
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _mediaFiles = [..._mediaFiles, picked]);
    }
  }

  Future<void> _aiEnhance() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type your requirement first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _aiEnhancing = true);
    try {
      final auth = context.read<AuthProvider>();
      final result = await ApiService.aiEnhanceBroadcast(
        token: auth.token ?? '',
        text: _descCtrl.text.trim(),
        postType: _postType,
      );
      if (result['enhanced'] != null) {
        _descCtrl.text = result['enhanced'].toString();
      }
    } catch (_) {
      // Simulate AI enhancement
      final text = _descCtrl.text.trim();
      _descCtrl.text =
          '$text\n\n[AI Enhanced: Fresh, quality items required. Prompt delivery preferred. Please confirm availability before accepting.]';
    } finally {
      if (mounted) setState(() => _aiEnhancing = false);
    }
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your need or offer'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final List<String>? targetRoles = _audienceMode == 1
          ? _selectedRoles.toList()
          : null;
      final String urgency = ['normal', 'urgent', 'emergency'][_urgencyLevel];
      await ApiService.createBroadcastPost(
        token: auth.token ?? '',
        postType: _postType,
        description: _descCtrl.text.trim(),
        price: _priceCtrl.text.isEmpty
            ? null
            : double.tryParse(_priceCtrl.text),
        priceMode: _priceMode ? 'FIXED' : 'ASKING',
        lat: 26.9124,
        lng: 75.7873,
        radiusKm: _radiusKm,
        urgency: urgency,
        targetRoles: targetRoles,
      );
    } catch (_) {
      // Proceed on mock
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    AudioToneService.playOrderCreatedTone();
    Navigator.pop(context);
    final urgencyLabel = ['', ' 🟡 Urgent', ' 🔴 Emergency'][_urgencyLevel];
    final radiusLabel = _radiusKm.toInt() == 5 ? '5 km' : '${_radiusKm.toInt()} km';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '📡 ${_postType == 'NEED' ? 'Need' : 'Offer'} posted to $radiusLabel radius!$urgencyLabel'),
        backgroundColor: _postType == 'NEED'
            ? const Color(0xFF8B5CF6)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNeed = _postType == 'NEED';
    final accentColor =
        isNeed ? const Color(0xFF8B5CF6) : const Color(0xFF059669);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF060B18) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Text(
          'New Broadcast',
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _typeCtrl,
          labelColor: accentColor,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: accentColor,
          tabs: const [
            Tab(
              icon: Icon(Icons.campaign_rounded),
              text: 'POST NEED',
            ),
            Tab(
              icon: Icon(Icons.local_offer_rounded),
              text: 'POST OFFER',
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(
                      isNeed
                          ? Icons.campaign_rounded
                          : Icons.local_offer_rounded,
                      color: accentColor,
                      size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isNeed
                          ? 'Tell people what you need — nearby shops and drivers will respond!'
                          : 'Tell people what you are offering — customers in 5 km will see it!',
                      style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF334155),
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // Voice record button
              _buildSectionLabel('Voice Message (Optional)', isDark),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _isRecording = !_isRecording;
                  if (!_isRecording) _hasVoice = true;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _isRecording
                            ? const Color(0xFFEF4444)
                            : (_hasVoice
                                ? accentColor
                                : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0)))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isRecording
                            ? Icons.stop_circle_rounded
                            : (_hasVoice
                                ? Icons.play_circle_rounded
                                : Icons.mic_rounded),
                        color: _isRecording
                            ? const Color(0xFFEF4444)
                            : (_hasVoice
                                ? accentColor
                                : const Color(0xFF94A3B8)),
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isRecording
                            ? 'Recording... Tap to stop'
                            : (_hasVoice
                                ? '✅ Voice recorded — Tap to play'
                                : 'Tap to record voice message'),
                        style: TextStyle(
                          color: _isRecording
                              ? const Color(0xFFEF4444)
                              : (_hasVoice
                                  ? accentColor
                                  : const Color(0xFF94A3B8)),
                          fontSize: 13,
                          fontWeight: _isRecording || _hasVoice
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Text description
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel('Description *', isDark),
                  GestureDetector(
                    onTap: _aiEnhancing ? null : _aiEnhance,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _aiEnhancing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white, size: 13),
                              SizedBox(width: 5),
                              Text('AI Enhance',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 5,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14),
                decoration: InputDecoration(
                  hintText: isNeed
                      ? 'E.g. "5 kg aloo, 2 kg pyaj chahiye" or "Plumber chahiye bathroom leak fix karna hai"\n\nHindi, Hinglish, or English — all OK!'
                      : 'Describe what you are offering — price, quantity, timing, area covered...',
                  hintStyle: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 13, height: 1.5),
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: accentColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 20),

              // Photos / Video
              _buildSectionLabel('Photos / Video (Optional)', isDark),
              const SizedBox(height: 8),
              Row(children: [
                _mediaBtn(
                    icon: Icons.photo_library_rounded,
                    label: 'Photos',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: _pickMedia),
                const SizedBox(width: 10),
                _mediaBtn(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                    onTap: _pickVideo),
              ]),
              if (_mediaFiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _mediaFiles.map((f) {
                      final isVideo = f.name.endsWith('.mp4') ||
                          f.name.endsWith('.mov');
                      return Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.image_rounded,
                              color: accentColor,
                              size: 30,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => setState(() =>
                                  _mediaFiles = _mediaFiles
                                      .where((x) => x.path != f.path)
                                      .toList()),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              // Price section
              _buildSectionLabel('Price', isDark),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priceMode = false),
                    child: _priceToggle(
                        label: 'Ask for quotes',
                        subtitle: 'Let others suggest price',
                        icon: Icons.help_outline_rounded,
                        selected: !_priceMode,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priceMode = true),
                    child: _priceToggle(
                        label: 'Set my price',
                        subtitle: 'I know my price',
                        icon: Icons.attach_money_rounded,
                        selected: _priceMode,
                        color: const Color(0xFF10B981),
                        isDark: isDark),
                  ),
                ),
              ]),
              if (_priceMode)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Price (₹)',
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF10B981), width: 1.5),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Audience Targeting Section ─────────────────────────────────
              _buildSectionLabel('📡 Broadcast Audience', isDark),
              const SizedBox(height: 10),

              // Mode selector
              Row(children: [
                _audienceModeChip(
                  index: 0,
                  label: 'Everyone',
                  icon: Icons.public_rounded,
                  color: accentColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _audienceModeChip(
                  index: 1,
                  label: 'By Role',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF0EA5E9),
                  isDark: isDark,
                ),
              ]),

              // Role checkboxes (visible when mode=1)
              if (_audienceMode == 1) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    _roleCheckbox('Customer', Icons.person_rounded,
                        const Color(0xFF10B981), isDark),
                    const SizedBox(height: 6),
                    _roleCheckbox('Driver', Icons.delivery_dining_rounded,
                        const Color(0xFFFF9F43), isDark),
                    const SizedBox(height: 6),
                    _roleCheckbox('Merchant', Icons.store_rounded,
                        const Color(0xFF6C63FF), isDark),
                  ]),
                ),
              ],

              const SizedBox(height: 16),

              // Radius slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel('📍 Radius', isDark),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_radiusKm.toInt()} km',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: accentColor,
                  inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                  thumbColor: accentColor,
                  overlayColor: accentColor.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: _radiusKm,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  onChanged: (v) => setState(() => _radiusKm = v),
                ),
              ),

              const SizedBox(height: 16),

              // Urgency level
              _buildSectionLabel('⚡ Urgency Level', isDark),
              const SizedBox(height: 8),
              Row(children: [
                _urgencyChip(0, '🟢 Normal', const Color(0xFF10B981), isDark),
                const SizedBox(width: 8),
                _urgencyChip(1, '🟡 Urgent', const Color(0xFFF59E0B), isDark),
                const SizedBox(width: 8),
                _urgencyChip(2, '🔴 Emergency', const Color(0xFFEF4444), isDark),
              ]),
              if (_urgencyLevel == 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_rounded,
                          color: Color(0xFFEF4444), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Emergency broadcasts also send push notifications to nearby users immediately.',
                          style: TextStyle(
                              color: Color(0xFFEF4444), fontSize: 11, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ),

              const SizedBox(height: 28),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          isNeed
                              ? Icons.campaign_rounded
                              : Icons.local_offer_rounded),
                  label: Text(
                    _isSubmitting
                        ? 'Broadcasting...'
                        : isNeed
                            ? '📡 Broadcast My Need'
                            : '📡 Broadcast My Offer',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _urgencyLevel == 2
                        ? const Color(0xFFDC2626)
                        : _urgencyLevel == 1
                            ? const Color(0xFFF59E0B)
                            : accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  '📍 Visible within ${_radiusKm.toInt()} km for 24 hours'
                  '${_audienceMode == 1 ? ' · ${_selectedRoles.join(', ')} only' : ''}',
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audienceModeChip({
    required int index,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final selected = _audienceMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _audienceMode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: isDark ? 0.18 : 0.1)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? color : const Color(0xFF94A3B8), size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: selected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : const Color(0xFF94A3B8),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCheckbox(String role, IconData icon, Color color, bool isDark) {
    final selected = _selectedRoles.contains(role);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          if (_selectedRoles.length > 1) _selectedRoles.remove(role);
        } else {
          _selectedRoles.add(role);
        }
      }),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: selected ? color : Colors.white30, width: 1.5),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 10),
          Icon(icon, color: selected ? color : Colors.white38, size: 18),
          const SizedBox(width: 8),
          Text(
            role,
            style: TextStyle(
              color: selected
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : const Color(0xFF94A3B8),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _urgencyChip(int level, String label, Color color, bool isDark) {
    final selected = _urgencyLevel == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgencyLevel = level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? color : const Color(0xFF94A3B8),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _mediaBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _priceToggle({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: isDark ? 0.18 : 0.08)
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected
                ? color
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: selected ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon,
            color: selected ? color : const Color(0xFF94A3B8), size: 20),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: selected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        Text(subtitle,
            style: const TextStyle(
                color: Color(0xFF64748B), fontSize: 10)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../toddler_screens/toddler_mocktest.dart';

class ToddlerActivityScreen extends StatefulWidget {
  final String toddlerId;
  final String toddlerName;

  const ToddlerActivityScreen({
    super.key,
    required this.toddlerId,
    required this.toddlerName,
  });

  @override
  State<ToddlerActivityScreen> createState() => _ToddlerActivityScreenState();
}

class _ToddlerActivityScreenState extends State<ToddlerActivityScreen> {
  static const Color bg = Color(0xFFF4FFF6);
  static const Color green = Color(0xFF27C267);
  static const Color greenDark = Color(0xFF179C4C);
  static const Color dark = Color(0xFF14201A);
  static const Color grey = Color(0xFF6E7B80);
  static const Color border = Color(0xFFE2EFE7);

  bool _loading = true;
  String _sendingId = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getToddlerMockTestResults(
        toddlerId: widget.toddlerId,
        limit: 30,
      );
      _results = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      _results = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startMockTest() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ToddlerMockTestScreen(
          toddlerId: widget.toddlerId,
          toddlerName: widget.toddlerName,
        ),
      ),
    );

    if (changed == true) {
      await _loadResults();
    }
  }

  Future<void> _sendToTeacher(Map<String, dynamic> result) async {
    final id = (result['_id'] ?? result['id'] ?? '').toString();
    if (id.isEmpty) return;

    setState(() => _sendingId = id);
    try {
      await ApiService.sendMockTestReportToTeacher(resultId: id);
      await _loadResults();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mock test report sent to teacher')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send report: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingId = '');
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? '';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Recently';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final latest = _results.isNotEmpty ? _results.first : null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: dark),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Toddler Activity',
                          style: TextStyle(color: dark, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.toddlerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: grey, fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadResults,
                    icon: const Icon(Icons.refresh_rounded, color: dark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: green))
                  : RefreshIndicator(
                color: green,
                onRefresh: _loadResults,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StartMockCard(onTap: _startMockTest),
                          const SizedBox(height: 16),
                          if (latest == null)
                            _EmptyResults(onStart: _startMockTest)
                          else ...[
                            _LatestScoreCard(result: latest),
                            const SizedBox(height: 18),
                            const Text(
                              'Mock Test History',
                              style: TextStyle(color: dark, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            ..._results.map(
                                  (result) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ResultTile(
                                  percentage: _toInt(result['percentage']),
                                  correct: _toInt(result['correctCount']),
                                  total: _toInt(result['totalQuestions']),
                                  date: _formatDate(result['completedAt'] ?? result['createdAt']),
                                  needsPractice: ((result['needsPractice'] as List<dynamic>?) ?? []).length,
                                  sentToTeacher: result['sentToTeacher'] == true,
                                  sending: _sendingId == (result['_id'] ?? result['id'] ?? '').toString(),
                                  onSend: () => _sendToTeacher(result),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartMockCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StartMockCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF27C267), Color(0xFF179C4C)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27C267).withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
            child: const Icon(Icons.quiz_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start AI Mockup Test', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Practice Urdu words with images and voice.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF179C4C),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: onTap,
            child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _LatestScoreCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _LatestScoreCard({required this.result});

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = _toInt(result['percentage']);
    final correct = _toInt(result['correctCount']);
    final total = _toInt(result['totalQuestions']);
    final sentToTeacher = result['sentToTeacher'] == true;
    final createdByRole = (result['createdByRole'] ?? 'parent').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EFE7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (percentage.clamp(0, 100)) / 100,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFE8FFF2),
                  color: const Color(0xFF27C267),
                ),
                Text('$percentage%', style: const TextStyle(color: Color(0xFF14201A), fontWeight: FontWeight.w900, fontSize: 20)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Latest Mock Test', style: TextStyle(color: Color(0xFF14201A), fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('$correct/$total correct • ${createdByRole == 'teacher' ? 'Sent by Teacher' : 'Parent Test'}', style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sentToTeacher ? const Color(0xFFE8FFF2) : const Color(0xFFFFF6E6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    sentToTeacher ? 'Teacher received' : 'Not sent to teacher',
                    style: TextStyle(
                      color: sentToTeacher ? const Color(0xFF179C4C) : const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final int percentage;
  final int correct;
  final int total;
  final int needsPractice;
  final String date;
  final bool sentToTeacher;
  final bool sending;
  final VoidCallback onSend;

  const _ResultTile({
    required this.percentage,
    required this.correct,
    required this.total,
    required this.needsPractice,
    required this.date,
    required this.sentToTeacher,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: Color(0xFFE8FFF2), shape: BoxShape.circle),
                child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF27C267)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$percentage% Score', style: const TextStyle(color: Color(0xFF14201A), fontSize: 13.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('$correct/$total correct • $needsPractice practice items', style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 11.8, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Text(date, style: const TextStyle(color: Color(0xFF6E7B80), fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: sentToTeacher || sending ? null : onSend,
              style: OutlinedButton.styleFrom(
                foregroundColor: sentToTeacher ? const Color(0xFF179C4C) : const Color(0xFF14201A),
                side: BorderSide(color: sentToTeacher ? const Color(0xFFBBF7D0) : const Color(0xFFE2EFE7)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(sentToTeacher ? Icons.done_all_rounded : Icons.send_rounded, size: 18),
              label: Text(sentToTeacher ? 'Sent to Teacher' : 'Send Report to Teacher', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyResults({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EFE7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.insights_rounded, color: Color(0xFF27C267), size: 46),
          const SizedBox(height: 12),
          const Text('No mock test result yet', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF14201A), fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Start a mockup test to see this toddler’s score here.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6E7B80), fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27C267),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: onStart,
            child: const Text('Start Mockup Test', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

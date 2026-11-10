import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/app_theme.dart';
import '../models/chat_message.dart';
import '../services/faculty_assistant.dart';
import '../services/firestore_faculty_repository.dart';
import '../widgets/chat_bubble.dart';

final facultyAssistantProvider = Provider<FacultyAssistant>(
  (ref) =>
      FacultyAssistant(FirestoreFacultyRepository(FirebaseFirestore.instance)),
);

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});
  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  List<String> _facultyIds = [];
  List<String> _dynamicTeacherNames = [];
  bool _busy = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loadFacultyNames();
  }

  Future<void> _loadFacultyNames() async {
    try {
      // Students cannot list users; the presence projection is the directory.
      final snap = await FirebaseFirestore.instance
          .collection('faculty_presence')
          .limit(3)
          .get(const GetOptions(source: Source.server));
      if (mounted) {
        setState(() {
          _dynamicTeacherNames = snap.docs
              .map((doc) => doc.data()['displayName'] as String? ?? 'Teacher')
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _send([String? suggestion]) async {
    if (_busy) return;
    final text = (suggestion ?? _input.text).trim();
    if (text.isEmpty) return;
    final request = ++_request;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage.user(text));
      _busy = true;
    });
    _scrollDown();
    final answer = await ref
        .read(facultyAssistantProvider)
        .answer(text, previousFacultyIds: _facultyIds)
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => const AssistantAnswer(
            'The lookup took too long. Check your connection and try again. No location has been verified.',
          ),
        );
    if (!mounted || request != _request) return;
    setState(() {
      if (answer.facultyIds.isNotEmpty) _facultyIds = answer.facultyIds;
      _messages.add(ChatMessage.ai(answer.text));
      _busy = false;
    });
    _scrollDown();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text),
        onPressed: () => _send(text),
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        labelStyle: const TextStyle(
          color: AppTheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  void dispose() {
    _request++;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Faculty assistant'),
      actions: [
        IconButton(
          tooltip: 'New conversation',
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: () {
            setState(() {
              _request++;
              _busy = false;
              _facultyIds = [];
              _messages.clear();
            });
          },
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Faculty records, explained clearly. No model download needed.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.neumorphicDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.travel_explore,
                              size: 40,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Who are you looking for?',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Ask for a faculty member’s location, schedule or availability. I’ll show what is recorded and say when it cannot be verified.',
                            ),
                            const SizedBox(height: 20),
                            for (final text in [
                              'Who has a recent location?',
                              'Who are the faculty members?',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: OutlinedButton(
                                  onPressed: () => _send(text),
                                  child: Text(text),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          'Try “Where is [full name]?” Then ask “What about their schedule tomorrow?”',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => ChatBubble(
                      message: _messages[index],
                      animationIndex: -1,
                    ),
                  ),
          ),
          if (_busy)
            Semantics(
              liveRegion: true,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Checking faculty records…'),
              ),
            ),
          if (_messages.isEmpty && !_busy)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildSuggestionChip('Who is available for consultation?'),
                  if (_dynamicTeacherNames.isEmpty) ...[
                    _buildSuggestionChip('Where is Mr. Mike?'),
                    _buildSuggestionChip('Who is in the Library?'),
                    _buildSuggestionChip('Is Mr. Mike busy?'),
                  ] else ...[
                    for (final name in _dynamicTeacherNames)
                      _buildSuggestionChip('Where is $name?'),
                    _buildSuggestionChip('Who is in the Library?'),
                  ],
                  _buildSuggestionChip('Who has a recent location?'),
                  _buildSuggestionChip('Computer Lab schedule'),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Name, location or schedule…',
                      labelText: 'Ask about faculty',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  tooltip: _busy ? 'Cancel lookup' : 'Send message',
                  onPressed: _busy
                      ? () => setState(() {
                          _request++;
                          _busy = false;
                          _messages.add(ChatMessage.ai('Lookup cancelled.'));
                        })
                      : () => _send(),
                  icon: Icon(_busy ? Icons.stop : Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

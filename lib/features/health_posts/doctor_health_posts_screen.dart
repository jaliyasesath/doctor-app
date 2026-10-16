import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/widgets/app_error_ui.dart';
import 'health_post_labels.dart';
import 'health_posts_service.dart';

const _teal = Color(0xFF0F766E);

class DoctorHealthPostsCard extends StatefulWidget {
  const DoctorHealthPostsCard({super.key});
  @override
  State<DoctorHealthPostsCard> createState() => _DoctorHealthPostsCardState();
}

class _DoctorHealthPostsCardState extends State<DoctorHealthPostsCard> {
  final _api = HealthPostsService();
  Map<String, dynamic>? _summary;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _api.summary();
      if (mounted) {
        setState(() {
          _summary = s;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    }
  }

  Future<void> _open({bool create = false}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorHealthPostsScreen(createOnOpen: create),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.article_outlined, color: _teal),
                title: const Text(
                  'My Health Posts',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle:
                    const Text('Share helpful updates with your community'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(),
              ),
              if (_failed)
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry loading posts'),
                )
              else if (_summary == null)
                const LinearProgressIndicator()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      for (final key in ['published', 'drafts'])
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${_summary![key] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(key == 'published' ? 'Published' : 'Drafts'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _summary?['canPublish'] == true
                        ? () => _open(create: true)
                        : null,
                    style: FilledButton.styleFrom(backgroundColor: _teal),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Post'),
                  ),
                  OutlinedButton(
                    onPressed: () => _open(),
                    child: const Text('View all'),
                  ),
                ],
              ),
              if (_summary?['canPublish'] == false)
                const Text('Publishing is available to verified doctors.'),
            ],
          ),
        ),
      );
}

class DoctorHealthPostsScreen extends StatefulWidget {
  const DoctorHealthPostsScreen({super.key, this.createOnOpen = false});
  final bool createOnOpen;
  @override
  State<DoctorHealthPostsScreen> createState() =>
      _DoctorHealthPostsScreenState();
}

class _DoctorHealthPostsScreenState extends State<DoctorHealthPostsScreen> {
  final _api = HealthPostsService();
  final _search = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  String _status = 'all', _language = 'en';
  String? _cursor, _error;
  bool _busy = false, _more = false;
  int _generation = 0;
  HealthPostLabels get l => HealthPostLabels(_language);
  @override
  void initState() {
    super.initState();
    _load();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _edit());
    }
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    if (next && (_busy || !_more)) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) {
        _items.clear();
        _cursor = null;
      }
    });
    try {
      final data = await _api.list(
        status: _status,
        search: _search.text.trim(),
        cursor: next ? _cursor : null,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = _items.map((e) => e['id']).toSet();
        _items.addAll(
          (data['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((e) => seen.add(e['id'])),
        );
        _cursor = data['nextCursor']?.toString();
        _more = data['hasMore'] == true;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'Unable to load posts. Please retry.';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorHealthPostEditor(post: item, language: _language),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('deleteQuestion')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('delete')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _api.delete(item['id'] as int, item['version'] as int);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(l.t('myPosts')),
          actions: [
            DropdownButton<String>(
              value: _language,
              items: healthLanguages.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _language = v);
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final status in ['all', 'published', 'drafts'])
                            ChoiceChip(
                              label: Text(l.t(status)),
                              selected: _status == status,
                              onSelected: (_) {
                                setState(() => _status = status);
                                _load();
                              },
                            ),
                          FilledButton.icon(
                            onPressed: () => _edit(),
                            icon: const Icon(Icons.add),
                            label: Text(l.t('create')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        maxLength: 100,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                          labelText: l.t('search'),
                          counterText: '',
                          suffixIcon: IconButton(
                            onPressed: () => _load(),
                            icon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  ListTile(
                    title: Text(_error!),
                    trailing: TextButton(
                      onPressed: () => _load(next: _items.isNotEmpty),
                      child: Text(l.t('retry')),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        if (_items.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(_busy ? '' : l.t('empty')),
                              ),
                            ],
                          );
                        }
                        if (c.maxWidth >= 850) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints:
                                        BoxConstraints(minWidth: c.maxWidth),
                                    child: DataTable(
                                      columns: [
                                        DataColumn(label: Text(l.t('title'))),
                                        DataColumn(label: Text(l.t('topic'))),
                                        DataColumn(
                                            label: Text(l.t('published'))),
                                        const DataColumn(label: Text('')),
                                      ],
                                      rows: _items
                                          .map(
                                            (p) => DataRow(
                                              cells: [
                                                DataCell(
                                                  SizedBox(
                                                    width: 280,
                                                    child: Text(
                                                      (p['title'] as String)
                                                              .isEmpty
                                                          ? p['content']
                                                              .toString()
                                                          : p['title']
                                                              .toString(),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  onTap: () => _edit(p),
                                                ),
                                                DataCell(Text(
                                                    p['topic'].toString())),
                                                DataCell(
                                                  Text(
                                                    p['isHidden'] == true
                                                        ? l.t('hidden')
                                                        : l.t(
                                                            p['isPublished'] ==
                                                                    true
                                                                ? 'published'
                                                                : 'drafts',
                                                          ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        tooltip: l.t('edit'),
                                                        onPressed: () =>
                                                            _edit(p),
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip: l.t('delete'),
                                                        onPressed: () =>
                                                            _delete(p),
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                                _loadMore(),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _items.length + 1,
                          itemBuilder: (context, i) {
                            if (i == _items.length) return _loadMore();
                            final p = _items[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: ListTile(
                                onTap: () => _edit(p),
                                title: Text(
                                  p['title'].toString().isEmpty
                                      ? p['content'].toString()
                                      : p['title'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${p['topic']} · ${l.t(p['isPublished'] == true ? 'published' : 'drafts')}${p['isHidden'] == true ? ' · ${l.t('hidden')}' : ''}',
                                ),
                                trailing: IconButton(
                                  tooltip: l.t('delete'),
                                  onPressed: () => _delete(p),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Widget _loadMore() => Padding(
        padding: const EdgeInsets.all(16),
        child: _more
            ? TextButton(
                onPressed: _busy
                    ? null
                    : () => _items.length >= 200 ? _load() : _load(next: true),
                child: Text(l.t(_items.length >= 200 ? 'restart' : 'more')),
              )
            : const SizedBox.shrink(),
      );
}

class DoctorHealthPostEditor extends StatefulWidget {
  const DoctorHealthPostEditor(
      {super.key, this.post, this.language = 'en', this.service});
  final Map<String, dynamic>? post;
  final String language;
  final HealthPostsService? service;
  @override
  State<DoctorHealthPostEditor> createState() => _DoctorHealthPostEditorState();
}

class _DoctorHealthPostEditorState extends State<DoctorHealthPostEditor> {
  late final _api = widget.service ?? HealthPostsService();
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _content, _source;
  late String _topic, _postLanguage;
  late final String _requestId;
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _topics = [];
  String? _path;
  bool _busy = false, _dirty = false, _remove = false, _topicsFailed = false;
  bool _leavePrompt = false;
  HealthPostLabels get l => HealthPostLabels(widget.language);
  @override
  void initState() {
    super.initState();
    _post =
        widget.post == null ? null : Map<String, dynamic>.from(widget.post!);
    _title = TextEditingController(text: _post?['title']?.toString() ?? '');
    _content = TextEditingController(text: _post?['content']?.toString() ?? '');
    _source = TextEditingController(
      text: _post?['sourceUrl']?.toString() ?? '',
    );
    _topic = _post?['topic']?.toString() ?? 'general';
    _postLanguage = _post?['language']?.toString() ?? widget.language;
    _requestId = _uuid();
    _loadTopics();
  }

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _loadTopics() async {
    try {
      final d = await _api.topics();
      if (mounted) {
        setState(() {
          _topics = (d['topics'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
          _topicsFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _topicsFailed = true);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      String? path;
      if (Platform.isWindows) {
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'Photos',
              extensions: ['jpg', 'jpeg', 'png', 'webp'],
            ),
          ],
        );
        path = file?.path;
      } else {
        path = (await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 2400,
          imageQuality: 85,
        ))
            ?.path;
      }
      if (path == null) return;
      final length = await File(path).length();
      if (!mounted) return;
      if (length > 4194304) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Choose a photo smaller than 4 MB.')));
        return;
      }
      if (mounted) {
        setState(() {
          _path = path;
          _remove = false;
          _dirty = true;
        });
      }
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error);
    }
  }

  Future<void> _save({required bool publish}) async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'requestId': _requestId,
        'expectedVersion': _post?['version'] ?? 0,
        'topic': _topic,
        'language': _postLanguage,
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'sourceUrl': _source.text.trim(),
      };
      // A new post first receives a durable private draft ID. Published content,
      // photo replacement/removal and status then commit together in one request.
      _post ??= await _api.create(body, _requestId);
      body['expectedVersion'] = _post!['version'];
      body['publish'] = publish;
      body['removePhoto'] = _remove;
      _post = await _api.compose(_post!['id'] as int, body, photoPath: _path);
      _path = null;
      _remove = false;
      _dirty = false;
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) AppErrorUi.show(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _canLeave() async {
    if (_busy) return false;
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.t('discard')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.t('confirm')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _preview() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _title.text,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(_content.text),
          const SizedBox(height: 16),
          if (_path != null)
            Image.file(File(_path!),
                height: 230,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                    height: 120,
                    child: Center(child: Icon(Icons.broken_image_outlined))))
          else if (!_remove && _post?['hasPhoto'] == true)
            HealthPostPhoto(
              identity: '${_post!['id']}:${_post!['version']}',
              load: () => _api.photoBytes(_post!['id'] as int),
            ),
          if (_source.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_source.text),
            ),
        ],
      );
  @override
  Widget build(BuildContext context) => PopScope<bool>(
        canPop: !_busy && !_dirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || _leavePrompt) return;
          _leavePrompt = true;
          try {
            final leave = await _canLeave();
            if (leave && context.mounted) {
              setState(() => _dirty = false);
              Navigator.pop(context, _post != null);
            }
          } finally {
            _leavePrompt = false;
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l.t(_post == null ? 'create' : 'edit')),
            actions: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l.t('preview')),
                            content: SizedBox(
                              width: 480,
                              child: SingleChildScrollView(child: _preview()),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(l.t('cancel')),
                              ),
                            ],
                          ),
                        ),
                child: Text(l.t('preview')),
              ),
            ],
          ),
          body: AbsorbPointer(
            absorbing: _busy,
            child: LayoutBuilder(
              builder: (context, c) {
                final editor = Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.t('medicalPrivacy'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_topicsFailed)
                        TextButton(
                          onPressed: _loadTopics,
                          child: Text(l.t('retry')),
                        ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('topic:${_topics.length}'),
                        initialValue: _topics.any((x) => x['id'] == _topic)
                            ? _topic
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.t('topic')),
                        items: _topics
                            .map(
                              (x) => DropdownMenuItem(
                                value: x['id'] as String,
                                child: Text(
                                  x[widget.language]?.toString() ??
                                      x['en'].toString(),
                                ),
                              ),
                            )
                            .toList(),
                        validator: (v) => v == null ? l.t('topic') : null,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _topic = v;
                              _dirty = true;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _postLanguage,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l.t('language')),
                        items: healthLanguages.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _postLanguage = v;
                              _dirty = true;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _title,
                        maxLength: 140,
                        decoration: InputDecoration(labelText: l.t('title')),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      TextFormField(
                        controller: _content,
                        maxLength: 5000,
                        minLines: 7,
                        maxLines: 16,
                        decoration: InputDecoration(labelText: l.t('content')),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? l.t('contentRequired')
                            : null,
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _source,
                        maxLength: 500,
                        decoration: InputDecoration(labelText: l.t('source')),
                        keyboardType: TextInputType.url,
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) return null;
                          final uri = Uri.tryParse(v!.trim());
                          return uri != null &&
                                  uri.scheme == 'https' &&
                                  uri.host.isNotEmpty &&
                                  uri.userInfo.isEmpty
                              ? null
                              : 'Use an HTTPS link';
                        },
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pick,
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: Text(l.t('photo')),
                          ),
                          if (_path != null ||
                              (!_remove && _post?['hasPhoto'] == true))
                            TextButton(
                              onPressed: () => setState(() {
                                _path = null;
                                _remove = true;
                                _dirty = true;
                              }),
                              child: Text(l.t('removePhoto')),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (c.maxWidth < 950) _preview(),
                    ],
                  ),
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: c.maxWidth >= 950
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: editor),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            l.t('preview'),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Divider(),
                                          _preview(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : editor,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : () => _save(publish: false),
                        child: Text(
                          l.t(_post?['isPublished'] == true ? 'save' : 'draft'),
                        ),
                      ),
                      if (_post?['isPublished'] != true)
                        FilledButton(
                          onPressed: _busy ? null : () => _save(publish: true),
                          style: FilledButton.styleFrom(backgroundColor: _teal),
                          child: Text(l.t('publish')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/health_posts/health_post_labels.dart';
import 'pp_client_session.dart';
import 'pp_client_config.dart';
import 'pp_client_theme.dart';
import 'pp_client_identity_display.dart';

class PPClientHealthFeed extends StatefulWidget {
  const PPClientHealthFeed({
    super.key,
    required this.session,
    required this.onDoctor,
    this.onMyQueue,
    this.onProfile,
  });
  final PPClientSession session;
  final Future<void> Function(int doctorId) onDoctor;
  final VoidCallback? onMyQueue, onProfile;
  @override
  State<PPClientHealthFeed> createState() => _PPClientHealthFeedState();
}

class _PPClientHealthFeedState extends State<PPClientHealthFeed> {
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _topics = [];
  final Set<String> _actions = {};
  String _mode = 'latest', _uiLanguage = 'en';
  String? _topic, _postLanguage, _cursor, _error;
  bool _busy = false, _more = false, _topicsError = false;
  int _generation = 0, _followingCount = 0;
  HealthPostLabels get l => HealthPostLabels(_uiLanguage);
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _preferences();
    _loadTopics();
    _load();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.extentAfter < 500 &&
          !_busy &&
          _more &&
          _items.length < 200) {
        _load(next: true);
      }
    });
  }

  void _sessionChanged() {
    if (!widget.session.signedIn && mounted) {
      _generation++;
      setState(() {
        _items.clear();
        _busy = false;
        _more = false;
        _error = 'Please sign in again.';
      });
    }
  }

  Future<void> _preferences() async {
    try {
      final p = await SharedPreferences.getInstance();
      final value = p.getString('pp_health_feed_language');
      if (mounted && healthLanguages.containsKey(value)) {
        setState(() => _uiLanguage = value!);
      }
    } catch (_) {
      /* Optional preference only. */
    }
  }

  Future<void> _language(String value) async {
    setState(() => _uiLanguage = value);
    try {
      await (await SharedPreferences.getInstance()).setString(
        'pp_health_feed_language',
        value,
      );
    } catch (_) {}
  }

  Future<void> _loadTopics() async {
    try {
      final d = await widget.session.healthTopics();
      if (mounted) {
        setState(() {
          _topics = (d['topics'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
          _topicsError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _topicsError = true);
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.session.removeListener(_sessionChanged);
    _scroll.dispose();
    super.dispose();
  }

  String _message(Object error) => error is PPClientError
      ? error.message
      : 'Unable to complete this action. Please retry.';
  Future<void> _load({bool next = false}) async {
    if (next && (_busy || !_more)) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) {
        _items.clear();
        _cursor = null;
        _more = false;
      }
    });
    try {
      final d = await widget.session.healthFeed(
        mode: _mode,
        topic: _topic,
        language: _postLanguage,
        cursor: next ? _cursor : null,
      );
      if (!mounted || generation != _generation || !widget.session.signedIn) {
        return;
      }
      setState(() {
        final ids = _items.map((p) => p['id']).toSet();
        _items.addAll(
          (d['items'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .where((p) => ids.add(p['id'])),
        );
        _followingCount = (d['followingCount'] as num?)?.toInt() ?? 0;
        _cursor = d['nextCursor']?.toString();
        _more = d['hasMore'] == true;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _action(Map<String, dynamic> post, String action) async {
    final key = action == 'follow'
        ? 'follow:${post['doctorId']}'
        : '$action:${post['id']}';
    if (!_actions.add(key)) return;
    setState(() {});
    final field = action == 'follow'
        ? 'isFollowing'
        : action == 'save'
        ? 'isSaved'
        : 'isHelpful';
    final value = post[field] != true;
    try {
      if (action == 'follow') {
        await widget.session.healthFollow(post['doctorId'] as int, value);
      } else {
        await widget.session.healthAction(post['id'] as int, action, value);
      }
      if (!mounted) return;
      setState(() {
        if (action == 'follow') {
          for (final p in _items.where(
            (p) => p['doctorId'] == post['doctorId'],
          )) {
            p[field] = value;
          }
          if (!value && _mode == 'following') {
            _items.removeWhere((p) => p['doctorId'] == post['doctorId']);
          }
        } else {
          post[field] = value;
          if (action == 'helpful') {
            post['helpfulCount'] =
                (post['helpfulCount'] as int) + (value ? 1 : -1);
          }
          if (action == 'save' && !value && _mode == 'saved') {
            _items.removeWhere((p) => p['id'] == post['id']);
          }
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _actions.remove(key));
      } else {
        _actions.remove(key);
      }
    }
  }

  Future<void> _report(Map<String, dynamic> post) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('report')),
        content: TextField(
          controller: controller,
          maxLength: 300,
          maxLines: 3,
          decoration: InputDecoration(labelText: l.t('reason')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 3) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(l.t('confirm')),
          ),
        ],
      ),
    );
    // Dialog text input may finish its closing animation after the future resolves.
    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    if (reason == null || !mounted) return;
    try {
      await widget.session.healthReport(post['id'] as int, reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.t('reportThanks'))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    }
  }

  Future<void> _share(Map<String, dynamic> p, BuildContext origin) async {
    try {
      final box = origin.findRenderObject() as RenderBox?;
      // Share public post text only. Never share authenticated media URLs or bearer tokens.
      await Share.share(
        '${p['isOfficial'] == true ? 'PP Health Team · Official' : ppClientDoctorName(p['doctorName'])}\n${p['title']}\n${p['content']}${p['sourceUrl'].toString().isEmpty ? '' : '\n${p['sourceUrl']}'}',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to share this post.')),
        );
      }
    }
  }

  void _navigate(VoidCallback? callback) {
    Navigator.pop(context);
    callback?.call();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PPClientTheme.isDark(context)
        ? const Color(0xFF080D16)
        : const Color(0xFFF5F8FF),
    appBar: AppBar(
      title: Text(l.t(_mode == 'saved' ? 'saved' : 'feed')),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Interface language',
          icon: const Icon(Icons.translate),
          onSelected: _language,
          itemBuilder: (_) => healthLanguages.entries
              .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
        ),
        IconButton(
          tooltip: l.t('saved'),
          icon: Icon(
            _mode == 'saved' ? Icons.bookmark : Icons.bookmark_outline,
          ),
          onPressed: () {
            setState(() => _mode = _mode == 'saved' ? 'latest' : 'saved');
            _load();
          },
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        await _loadTopics();
        await _load();
      },
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.t('topics'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: Text(l.t('all')),
                            selected: _topic == null,
                            onSelected: (_) {
                              setState(() => _topic = null);
                              _load();
                            },
                          ),
                          for (final t in _topics)
                            ChoiceChip(
                              label: Text(
                                t[_uiLanguage]?.toString() ??
                                    t['en'].toString(),
                              ),
                              selected: _topic == t['id'],
                              onSelected: (_) {
                                setState(() => _topic = t['id'] as String);
                                _load();
                              },
                            ),
                        ],
                      ),
                      if (_topicsError)
                        TextButton(
                          onPressed: _loadTopics,
                          child: Text(l.t('retry')),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final mode in ['latest', 'following'])
                            TextButton(
                              onPressed: () {
                                setState(() => _mode = mode);
                                _load();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: _mode == mode
                                    ? PPClientTheme.accent(context)
                                    : PPClientTheme.muted(context),
                              ),
                              child: Text(
                                l.t(mode),
                                style: TextStyle(
                                  fontWeight: _mode == mode
                                      ? FontWeight.w800
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 220,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _postLanguage ?? 'all',
                              underline: const SizedBox.shrink(),
                              items: [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text(
                                    l.t('allLanguages'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...healthLanguages.entries.map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setState(
                                  () => _postLanguage = v == 'all' ? null : v,
                                );
                                _load();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_busy) const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (_error != null)
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(_error!),
                trailing: TextButton(
                  onPressed: () => _load(next: _items.isNotEmpty),
                  child: Text(l.t('retry')),
                ),
              ),
            ),
          if (!_busy && _error == null && _items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.article_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l.t(
                        _mode == 'following' && _followingCount == 0
                            ? 'noFollowing'
                            : 'empty',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_mode == 'following' && _followingCount == 0)
                      TextButton(
                        onPressed: () {
                          setState(() => _mode = 'latest');
                          _load();
                        },
                        child: Text(l.t('explore')),
                      ),
                  ],
                ),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _postCard(_items[i]),
                ),
              ),
              childCount: _items.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: _more
                    ? TextButton(
                        onPressed: _busy
                            ? null
                            : () => _items.length >= 200
                                  ? _load()
                                  : _load(next: true),
                        child: Text(
                          l.t(_items.length >= 200 ? 'restart' : 'more'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (i) => _navigate(
        i == 1
            ? widget.onMyQueue
            : i == 2
            ? widget.onProfile
            : null,
      ),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.format_list_numbered),
          label: 'My Queue',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
  Future<void> _officialInfo() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('PP Health Team'),
      content: const Text(
        'Official health tips and announcements from PP Care. These posts provide general information and do not replace advice from your doctor.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  Widget _postCard(Map<String, dynamic> p) {
    final official = p['isOfficial'] == true;
    final candidate = ppClientPhotoUrl(p['profilePhotoUrl']);
    final photoUri = candidate == null ? null : Uri.tryParse(candidate);
    final photo =
        photoUri != null &&
            photoUri.origin == PPClientConfig.origin.origin &&
            photoUri.path.startsWith('/uploads/doctors/')
        ? candidate
        : null;
    final date = DateTime.tryParse(
      p['publishedAt']?.toString() ?? '',
    )?.toLocal();
    final compact =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
        _uiLanguage != 'en';
    final followButton = OutlinedButton.icon(
      onPressed: _actions.contains('follow:${p['doctorId']}')
          ? null
          : () => _action(p, 'follow'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(p['isFollowing'] == true ? Icons.check : Icons.add, size: 16),
      label: Text(l.t(p['isFollowing'] == true ? 'following' : 'follow')),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: PPClientTheme.surface(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => official
                      ? _officialInfo()
                      : widget.onDoctor(p['doctorId'] as int),
                  child: CircleAvatar(
                    radius: 22,
                    child: official
                        ? const Icon(Icons.health_and_safety_outlined)
                        : photo == null
                        ? const Icon(Icons.person_outline)
                        : ClipOval(
                            child: Image.network(
                              photo,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person_outline),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => official
                        ? _officialInfo()
                        : widget.onDoctor(p['doctorId'] as int),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                official
                                    ? 'PP Health Team'
                                    : ppClientDoctorName(p['doctorName']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: PPClientTheme.accent(context),
                            ),
                          ],
                        ),
                        Text(
                          '${official ? 'Official' : p['specialization'] ?? ''}${date == null ? '' : ' · ${date.day}/${date.month}'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: PPClientTheme.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!official && !compact) followButton,
                PopupMenuButton<String>(
                  onSelected: (v) =>
                      v == 'report' ? _report(p) : _action(p, 'follow'),
                  itemBuilder: (_) => [
                    if (!official)
                      PopupMenuItem(
                        value: 'follow',
                        child: Text(
                          l.t(p['isFollowing'] == true ? 'unfollow' : 'follow'),
                        ),
                      ),
                    PopupMenuItem(value: 'report', child: Text(l.t('report'))),
                  ],
                ),
              ],
            ),
            if (!official && compact)
              Align(alignment: Alignment.centerLeft, child: followButton),
            const SizedBox(height: 10),
            if (p['title'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  p['title'].toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            _ExpandableHealthText(text: p['content'].toString(), labels: l),
            const SizedBox(height: 12),
            if (p['hasPhoto'] == true)
              HealthPostPhoto(
                key: ValueKey('${p['id']}:${p['version']}'),
                identity: '${p['id']}:${p['version']}',
                load: () => widget.session.healthPhoto(p['id'] as int),
              ),
            if (p['sourceUrl'].toString().isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(p['sourceUrl'].toString());
                  if (uri != null &&
                      uri.scheme == 'https' &&
                      uri.userInfo.isEmpty) {
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unable to open source.'),
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l.t('sourceOpen')),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _actions.contains('helpful:${p['id']}')
                      ? null
                      : () => _action(p, 'helpful'),
                  icon: Icon(
                    p['isHelpful'] == true
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    size: 20,
                  ),
                  label: Text('${l.t('helpful')} ${p['helpfulCount']}'),
                ),
                TextButton.icon(
                  onPressed: _actions.contains('save:${p['id']}')
                      ? null
                      : () => _action(p, 'save'),
                  icon: Icon(
                    p['isSaved'] == true
                        ? Icons.bookmark
                        : Icons.bookmark_outline,
                    size: 20,
                  ),
                  label: Text(l.t('save')),
                ),
                Builder(
                  builder: (origin) => TextButton.icon(
                    onPressed: () => _share(p, origin),
                    icon: const Icon(Icons.ios_share, size: 20),
                    label: Text(l.t('share')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableHealthText extends StatefulWidget {
  const _ExpandableHealthText({required this.text, required this.labels});
  final String text;
  final HealthPostLabels labels;
  @override
  State<_ExpandableHealthText> createState() => _ExpandableHealthTextState();
}

class _ExpandableHealthTextState extends State<_ExpandableHealthText> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = DefaultTextStyle.of(
        context,
      ).style.merge(const TextStyle(height: 1.5));
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: 4,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final truncated = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: style,
          ),
          if (truncated)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(widget.labels.t(_expanded ? 'less' : 'readMore')),
            ),
        ],
      );
    },
  );
}

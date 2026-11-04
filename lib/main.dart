/*
  Nama : Syahwa Aliah Wandi
  NIM  : 825240139
  Tugas TakeHome 5
*/

import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ===================== COLOR PALETTE =====================
const Color darkRed = Color(0xFFA32638);
const Color deepRed = Color(0xFF5C0F1B);
const Color darkGrey = Color(0xFF1B1B1F);
const Color midGrey = Color(0xFF2A2A30);
const Color lightGrey = Color(0xFFB4B4BC);

void main() {
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: darkGrey,
        colorScheme: const ColorScheme.dark(
          primary: darkRed,
          secondary: darkRed,
          surface: darkGrey,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: deepRed,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: midGrey,
          indicatorColor: darkRed,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, color: lightGrey),
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: darkRed,
          thumbColor: darkRed,
          inactiveTrackColor: midGrey,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

// ===================== MODEL =====================
class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String artwork;
  final String previewUrl;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artwork,
    required this.previewUrl,
  });

  factory Song.fromItunes(Map<String, dynamic> j) => Song(
    id: j['trackId'] ?? 0,
    title: j['trackName'] ?? 'Tanpa Judul',
    artist: j['artistName'] ?? 'Tanpa Artis',
    album: j['collectionName'] ?? '-',
    artwork: ((j['artworkUrl100'] ?? '') as String).replaceAll(
      '100x100',
      '400x400',
    ),
    previewUrl: j['previewUrl'] ?? '',
  );

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    id: j['id'],
    title: j['title'],
    artist: j['artist'],
    album: j['album'],
    artwork: j['artwork'],
    previewUrl: j['previewUrl'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'artwork': artwork,
    'previewUrl': previewUrl,
  };
}

class Playlist {
  final String id;
  String name;
  final List<Song> songs;

  Playlist({required this.id, required this.name, required this.songs});

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
    id: j['id'],
    name: j['name'],
    songs: (j['songs'] as List)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songs': songs.map((s) => s.toJson()).toList(),
  };
}

enum RepeatMode { off, all, one }

// ===================== PLAYER CONTROLLER =====================
class PlayerController extends ChangeNotifier {
  final AudioPlayer _audio = AudioPlayer();
  SharedPreferences? _prefs;

  List<Song> queue = [];
  int index = -1;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool shuffle = false;
  RepeatMode repeat = RepeatMode.off;

  List<Song> favorites = [];
  List<Song> history = [];
  List<Playlist> playlists = [];
  String name = 'Syahwa';

  Song? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    favorites = _loadList('favorites');
    history = _loadList('history');
    playlists = _loadPlaylists();
    name = _prefs!.getString('name') ?? name;

    _audio.onPlayerStateChanged.listen((s) {
      isPlaying = s == PlayerState.playing;
      notifyListeners();
    });
    _audio.onPositionChanged.listen((p) {
      position = p;
      notifyListeners();
    });
    _audio.onDurationChanged.listen((d) {
      duration = d;
      notifyListeners();
    });
    _audio.onPlayerComplete.listen((_) => _onComplete());
    notifyListeners();
  }

  List<Song> _loadList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveList(String key, List<Song> list) async {
    await _prefs?.setString(
      key,
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
  }

  List<Playlist> _loadPlaylists() {
    final raw = _prefs?.getString('playlists');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePlaylists() async {
    await _prefs?.setString(
      'playlists',
      jsonEncode(playlists.map((p) => p.toJson()).toList()),
    );
  }

  // ---------- playback ----------
  Future<void> playQueue(List<Song> list, int i) async {
    queue = List.of(list);
    await _playIndex(i);
  }

  Future<void> _playIndex(int i) async {
    final song = queue[i];
    index = i;
    position = Duration.zero;
    duration = Duration.zero;
    notifyListeners();
    try {
      await _audio.stop();
      await _audio.setSourceUrl(song.previewUrl);
      await _audio.resume();
      _addHistory(song);
    } catch (e) {
      debugPrint('Gagal memutar: $e');
    }
  }

  void _addHistory(Song s) {
    history.removeWhere((h) => h.id == s.id);
    history.insert(0, s);
    if (history.length > 30) history = history.sublist(0, 30);
    _saveList('history', history);
    notifyListeners();
  }

  Future<void> toggle() async {
    if (current == null) return;
    if (isPlaying) {
      await _audio.pause();
    } else {
      await _audio.resume();
    }
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    int n;
    if (shuffle && queue.length > 1) {
      final random = DateTime.now().microsecondsSinceEpoch % (queue.length - 1);
      n = (index + 1 + random) % queue.length;
    } else {
      n = index + 1;
      if (n >= queue.length) {
        if (repeat == RepeatMode.all) {
          n = 0;
        } else {
          await _audio.stop();
          position = Duration.zero;
          notifyListeners();
          return;
        }
      }
    }
    await _playIndex(n);
  }

  Future<void> prev() async {
    if (queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    await _playIndex(index > 0 ? index - 1 : queue.length - 1);
  }

  Future<void> seek(Duration d) => _audio.seek(d);

  void _onComplete() {
    if (repeat == RepeatMode.one) {
      _playIndex(index);
    } else {
      next();
    }
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = RepeatMode.values[(repeat.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  // ---------- favorites, history, profile ----------
  bool isFav(Song s) => favorites.any((f) => f.id == s.id);

  void toggleFav(Song s) {
    if (isFav(s)) {
      favorites.removeWhere((f) => f.id == s.id);
    } else {
      favorites.insert(0, s);
    }
    _saveList('favorites', favorites);
    notifyListeners();
  }

  void clearHistory() {
    history = [];
    _saveList('history', history);
    notifyListeners();
  }

  void setName(String n) {
    name = n.trim().isEmpty ? name : n.trim();
    _prefs?.setString('name', name);
    notifyListeners();
  }

  // ---------- playlists ----------
  Playlist? playlistById(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool inPlaylist(Playlist p, Song s) => p.songs.any((x) => x.id == s.id);

  Playlist? createPlaylist(String n) {
    final t = n.trim();
    if (t.isEmpty) return null;
    final p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: t,
      songs: <Song>[],
    );
    playlists.insert(0, p);
    _savePlaylists();
    notifyListeners();
    return p;
  }

  void renamePlaylist(Playlist p, String n) {
    final t = n.trim();
    if (t.isEmpty) return;
    p.name = t;
    _savePlaylists();
    notifyListeners();
  }

  void deletePlaylist(Playlist p) {
    playlists.removeWhere((x) => x.id == p.id);
    _savePlaylists();
    notifyListeners();
  }

  bool addToPlaylist(Playlist p, Song s) {
    if (inPlaylist(p, s)) return false;
    p.songs.add(s);
    _savePlaylists();
    notifyListeners();
    return true;
  }

  void removeFromPlaylist(Playlist p, Song s) {
    p.songs.removeWhere((x) => x.id == s.id);
    _savePlaylists();
    notifyListeners();
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }
}

String fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: midGrey,
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nama playlist'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

Future<void> showAddToPlaylistSheet(
  BuildContext context,
  PlayerController pc,
  Song song,
) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: midGrey,
    builder: (ctx) => ListenableBuilder(
      listenable: pc,
      builder: (_, __) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tambah ke Playlist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: darkRed),
              title: const Text('Playlist baru'),
              onTap: () async {
                final n = await showNameDialog(ctx, title: 'Playlist Baru');
                if (n == null) return;
                final p = pc.createPlaylist(n);
                if (p == null) return;
                pc.addToPlaylist(p, song);
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(content: Text('Ditambahkan ke "${p.name}"')),
                );
              },
            ),
            if (pc.playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Belum ada playlist.',
                  style: TextStyle(color: lightGrey),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: pc.playlists.map((p) {
                    final added = pc.inPlaylist(p, song);
                    return ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(p.name, maxLines: 1),
                      subtitle: Text(
                        '${p.songs.length} lagu',
                        style: const TextStyle(color: lightGrey),
                      ),
                      trailing: added
                          ? const Icon(Icons.check, color: darkRed)
                          : null,
                      onTap: () {
                        final ok = pc.addToPlaylist(p, song);
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Ditambahkan ke "${p.name}"'
                                  : 'Lagu sudah ada di "${p.name}"',
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const FadeSlideIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index % 8) * 60),
      curve: Curves.easeOut,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// ===================== NAVIGATOR AND MINI PLAYER =====================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final PlayerController pc = PlayerController();
  int tab = 0;

  @override
  void initState() {
    super.initState();
    pc.init();
  }

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    final n = await showNameDialog(context, title: 'Playlist Baru');
    if (n != null) pc.createPlaylist(n);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Cari Lagu', 'Favorit', 'Playlist', 'Riwayat', 'Profil'];
    final pages = [
      SearchPage(pc: pc),
      SongListPage(
        pc: pc,
        source: () => pc.favorites,
        emptyText: 'Belum ada lagu favorit.\nTap ikon hati di lagu.',
      ),
      PlaylistPage(pc: pc, onCreate: _createPlaylist),
      SongListPage(
        pc: pc,
        source: () => pc.history,
        emptyText: 'Belum ada riwayat putar.',
        action: IconButton(
          onPressed: pc.clearHistory,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Hapus riwayat',
        ),
      ),
      ProfilePage(pc: pc),
    ];

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(titles[tab], key: ValueKey(tab)),
        ),
        actions: [
          if (tab == 2)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Playlist baru',
              onPressed: _createPlaylist,
            ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: List.generate(
          pages.length,
          (i) => AnimatedOpacity(
            opacity: tab == i ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: pages[i],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: MiniPlayer(pc: pc),
          ),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: 'Cari'),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                label: 'Favorit',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music),
                label: 'Playlist',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'Riwayat',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Profil',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================== SONG TILE =====================
class SongTile extends StatelessWidget {
  final PlayerController pc;
  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const SongTile({
    super.key,
    required this.pc,
    required this.song,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = pc.current?.id == song.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isActive ? deepRed.withOpacity(0.35) : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            song.artwork,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 52,
              height: 52,
              color: midGrey,
              child: const Icon(Icons.music_note),
            ),
          ),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: lightGrey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: lightGrey),
                tooltip: 'Hapus dari playlist',
                onPressed: onRemove,
              )
            else
              IconButton(
                icon: const Icon(Icons.playlist_add, color: lightGrey),
                tooltip: 'Tambah ke playlist',
                onPressed: () => showAddToPlaylistSheet(context, pc, song),
              ),
            IconButton(
              // heart icon zooms when toggled
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  pc.isFav(song) ? Icons.favorite : Icons.favorite_border,
                  key: ValueKey(pc.isFav(song)),
                  color: darkRed,
                ),
              ),
              onPressed: () => pc.toggleFav(song),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== SEARCH PAGE =====================
class SearchPage extends StatefulWidget {
  final PlayerController pc;
  const SearchPage({super.key, required this.pc});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  List<Song> songs = [];
  bool loading = false;
  String? message = 'Cari judul lagu atau artis favoritmu.';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Fetch songs from the iTunes Search API
  Future<void> searchSongs() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final url = Uri.https('itunes.apple.com', '/search', {
        'term': q,
        'entity': 'song',
        'limit': '25',
      });
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = (data['results'] as List)
            .map((e) => Song.fromItunes(e as Map<String, dynamic>))
            .where((s) => s.previewUrl.isNotEmpty)
            .toList();
        setState(() {
          songs = results;
          message = results.isEmpty ? 'Lagu tidak ditemukan.' : null;
        });
      } else {
        setState(() => message = 'Server error (${res.statusCode}).');
      }
    } catch (e) {
      setState(() => message = 'Gagal mencari lagu. Cek koneksi internet.');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onSubmitted: (_) => searchSongs(),
            decoration: InputDecoration(
              hintText: 'Judul lagu atau artis',
              filled: true,
              fillColor: midGrey,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: searchSongs,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(color: darkRed),
          if (message != null)
            Expanded(
              child: Center(
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: lightGrey),
                ),
              ),
            )
          else
            Expanded(
              child: ListenableBuilder(
                listenable: widget.pc,
                builder: (_, __) => ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (_, i) => FadeSlideIn(
                    index: i,
                    child: SongTile(
                      pc: widget.pc,
                      song: songs[i],
                      onTap: () => widget.pc.playQueue(songs, i),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===================== FAVORITES AND HISTORY PAGE =====================
class SongListPage extends StatelessWidget {
  final PlayerController pc;
  final List<Song> Function() source;
  final String emptyText;
  final Widget? action;

  const SongListPage({
    super.key,
    required this.pc,
    required this.source,
    required this.emptyText,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pc,
      builder: (_, __) {
        final list = source();
        if (list.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: lightGrey),
            ),
          );
        }
        return Column(
          children: [
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action!),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => FadeSlideIn(
                  index: i,
                  child: SongTile(
                    pc: pc,
                    song: list[i],
                    onTap: () => pc.playQueue(list, i),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===================== PLAYLIST ====================
class PlaylistCover extends StatelessWidget {
  final Playlist playlist;
  final double size;
  const PlaylistCover({super.key, required this.playlist, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: midGrey,
      child: Icon(Icons.queue_music, size: size * 0.5, color: lightGrey),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: playlist.songs.isEmpty
          ? placeholder
          : Image.network(
              playlist.songs.first.artwork,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}

class PlaylistPage extends StatelessWidget {
  final PlayerController pc;
  final VoidCallback onCreate;
  const PlaylistPage({super.key, required this.pc, required this.onCreate});

  Future<void> _rename(BuildContext context, Playlist p) async {
    final n = await showNameDialog(
      context,
      title: 'Ubah Nama Playlist',
      initial: p.name,
    );
    if (n != null) pc.renamePlaylist(p, n);
  }

  Future<void> _delete(BuildContext context, Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: midGrey,
        title: const Text('Hapus Playlist'),
        content: Text('Hapus playlist "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) pc.deletePlaylist(p);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pc,
      builder: (_, __) {
        final list = pc.playlists;
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.queue_music, size: 64, color: lightGrey),
                const SizedBox(height: 12),
                const Text(
                  'Belum ada playlist.',
                  style: TextStyle(color: lightGrey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: darkRed),
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Buat Playlist'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final p = list[i];
            return FadeSlideIn(
              index: i,
              child: ListTile(
                leading: PlaylistCover(playlist: p),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${p.songs.length} lagu',
                  style: const TextStyle(color: lightGrey),
                ),
                trailing: PopupMenuButton<String>(
                  color: midGrey,
                  onSelected: (v) {
                    if (v == 'rename') _rename(context, p);
                    if (v == 'delete') _delete(context, p);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlaylistDetailPage(pc: pc, playlistId: p.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class PlaylistDetailPage extends StatelessWidget {
  final PlayerController pc;
  final String playlistId;
  const PlaylistDetailPage({
    super.key,
    required this.pc,
    required this.playlistId,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pc,
      builder: (context, _) {
        final p = pc.playlistById(playlistId);
        if (p == null) return const Scaffold(body: SizedBox());
        return Scaffold(
          appBar: AppBar(
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Ubah nama',
                onPressed: () async {
                  final n = await showNameDialog(
                    context,
                    title: 'Ubah Nama Playlist',
                    initial: p.name,
                  );
                  if (n != null) pc.renamePlaylist(p, n);
                },
              ),
            ],
          ),
          body: p.songs.isEmpty
              ? const Center(
                  child: Text(
                    'Playlist masih kosong.\nTap ikon + di daftar lagu untuk menambahkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: lightGrey),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          PlaylistCover(playlist: p, size: 72),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${p.songs.length} lagu',
                                  style: const TextStyle(color: lightGrey),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: darkRed,
                                  ),
                                  onPressed: () => pc.playQueue(p.songs, 0),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Putar Semua'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: p.songs.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          index: i,
                          child: SongTile(
                            pc: pc,
                            song: p.songs[i],
                            onTap: () => pc.playQueue(p.songs, i),
                            onRemove: () => pc.removeFromPlaylist(p, p.songs[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: MiniPlayer(pc: pc),
        );
      },
    );
  }
}

// ===================== PROFILE USER =====================
class ProfilePage extends StatelessWidget {
  final PlayerController pc;
  const ProfilePage({super.key, required this.pc});

  Future<void> _editName(BuildContext context) async {
    final c = TextEditingController(text: pc.name);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: midGrey,
        title: const Text('Ubah Nama'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              pc.setName(c.text);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pc,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: darkRed,
              child: Text(
                pc.name.isEmpty ? '?' : pc.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                pc.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editName(context),
              ),
            ],
          ),
          const Center(
            child: Text(
              'Sistem Informasi - Universitas Tarumanagara',
              style: TextStyle(color: lightGrey),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _stat('Favorit', pc.favorites.length, Icons.favorite),
              const SizedBox(width: 12),
              _stat('Playlist', pc.playlists.length, Icons.queue_music),
              const SizedBox(width: 12),
              _stat('Riwayat', pc.history.length, Icons.history),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Terakhir diputar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (pc.history.isEmpty)
            const Text('Belum ada.', style: TextStyle(color: lightGrey))
          else
            ...pc.history
                .take(3)
                .map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(s.artwork, width: 44, height: 44),
                    ),
                    title: Text(s.title, maxLines: 1),
                    subtitle: Text(
                      s.artist,
                      maxLines: 1,
                      style: const TextStyle(color: lightGrey),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Data lagu dari iTunes Search API (preview 30 detik)',
              style: TextStyle(color: lightGrey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int n, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: midGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: darkRed),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(
              '$n',
              key: ValueKey(n),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Text(label, style: const TextStyle(color: lightGrey)),
        ],
      ),
    ),
  );
}

// ===================== MINI PLAYER (PREVIEW) =====================
class MiniPlayer extends StatelessWidget {
  final PlayerController pc;
  const MiniPlayer({super.key, required this.pc});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pc,
      builder: (context, _) {
        final s = pc.current;
        if (s == null) return const SizedBox.shrink();
        final total = pc.duration.inMilliseconds;
        final progress = total == 0 ? 0.0 : pc.position.inMilliseconds / total;
        return Material(
          color: deepRed,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 350),
                pageBuilder: (_, __, ___) => PlayerPage(pc: pc),
                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(
                        CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              ),
            ),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 2,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
                ListTile(
                  dense: true,
                  // Hero: artwork flies to the full player
                  leading: Hero(
                    tag: 'artwork',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(s.artwork, width: 40, height: 40),
                    ),
                  ),
                  title: Text(s.title, maxLines: 1),
                  subtitle: Text(
                    s.artist,
                    maxLines: 1,
                    style: const TextStyle(color: lightGrey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Icon(
                            pc.isPlaying ? Icons.pause : Icons.play_arrow,
                            key: ValueKey(pc.isPlaying),
                          ),
                        ),
                        onPressed: pc.toggle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: pc.next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===================== FULL PLAYER =====================
class PlayerPage extends StatelessWidget {
  final PlayerController pc;
  const PlayerPage({super.key, required this.pc});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pc,
      builder: (context, _) {
        final s = pc.current;
        if (s == null) return const Scaffold(body: SizedBox());
        final maxMs =
            (pc.duration.inMilliseconds > 0 ? pc.duration.inMilliseconds : 1)
                .toDouble();
        final posMs = pc.position.inMilliseconds
            .clamp(0, maxMs.toInt())
            .toDouble();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sedang Diputar'),
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [deepRed, darkGrey],
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Hero(
                      tag: 'artwork',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          s.artwork,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 260,
                            height: 260,
                            color: midGrey,
                            child: const Icon(Icons.music_note, size: 80),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      // title and artist cross-fade when the song changes
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey(s.id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              s.artist,
                              style: const TextStyle(color: lightGrey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 30,
                      tooltip: 'Tambah ke playlist',
                      icon: const Icon(Icons.playlist_add, color: Colors.white),
                      onPressed: () => showAddToPlaylistSheet(context, pc, s),
                    ),
                    IconButton(
                      iconSize: 30,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Icon(
                          pc.isFav(s) ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(pc.isFav(s)),
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () => pc.toggleFav(s),
                    ),
                  ],
                ),
                Slider(
                  value: posMs,
                  max: maxMs,
                  onChanged: (v) => pc.seek(Duration(milliseconds: v.toInt())),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fmt(pc.position),
                        style: const TextStyle(color: lightGrey),
                      ),
                      Text(
                        fmt(pc.duration),
                        style: const TextStyle(color: lightGrey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: pc.shuffle ? Colors.white : lightGrey,
                      ),
                      onPressed: pc.toggleShuffle,
                    ),
                    IconButton(
                      iconSize: 38,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: pc.prev,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: darkRed,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 44,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Icon(
                            pc.isPlaying ? Icons.pause : Icons.play_arrow,
                            key: ValueKey(pc.isPlaying),
                          ),
                        ),
                        onPressed: pc.toggle,
                      ),
                    ),
                    IconButton(
                      iconSize: 38,
                      icon: const Icon(Icons.skip_next),
                      onPressed: pc.next,
                    ),
                    IconButton(
                      icon: Icon(
                        pc.repeat == RepeatMode.one
                            ? Icons.repeat_one
                            : Icons.repeat,
                        color: pc.repeat == RepeatMode.off
                            ? lightGrey
                            : Colors.white,
                      ),
                      onPressed: pc.cycleRepeat,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
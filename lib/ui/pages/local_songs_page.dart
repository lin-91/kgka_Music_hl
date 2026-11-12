import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/liquid_glass_ui.dart';
import '../design_tokens.dart';
import '../adaptive_layout.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/local_music_controller.dart';
import '../../core/folder_filter.dart';
import '../widgets/toast.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_badge.dart';
import '../widgets/status_bar_overlay.dart';

class LocalSongsPage extends StatefulWidget {
  const LocalSongsPage({
    super.key,
    required this.player,
    required this.localMusic,
    this.auth,
  });

  final PlayerController player;
  final LocalMusicController localMusic;
  final AuthController? auth;

  @override
  State<LocalSongsPage> createState() => _LocalSongsPageState();
}

class _LocalSongsPageState extends State<LocalSongsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// 是否按文件夹分组展示。
  bool _grouped = false;

  /// 已折叠的分组（key 为规范化文件夹路径）。
  final Set<String> _collapsedFolders = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _requestPermission() async {
    final granted = await widget.localMusic.requestPermission();
    if (granted) {
      Toast.success('授权成功，正在扫描本地音乐');
    } else {
      Toast.error('未授予音频访问权限');
    }
  }

  /// 打开「扫描目录设置」：勾选/取消勾选文件夹以排除录音等目录。
  void _showFolderFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return AnimatedBuilder(
          animation: widget.localMusic,
          builder: (context, _) {
            final folders = widget.localMusic.availableFolders;
            final excludedCount = widget.localMusic.excludedFolders.length;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '扫描目录设置',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (excludedCount > 0)
                            TextButton(
                              onPressed: () => widget.localMusic
                                  .clearExcludedFolders(),
                              child: const Text('恢复全部'),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Text(
                        '取消勾选的文件夹将从本地音乐中排除（例如录音文件夹），'
                        '其子目录中的音频也不会显示。',
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Flexible(
                      child: folders.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  '未扫描到任何音频文件夹',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: folders.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                indent: 56,
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: .3),
                              ),
                              itemBuilder: (context, index) {
                                final entry = folders[index];
                                final folder = entry.folder;
                                final excluded =
                                    widget.localMusic.isFolderExcluded(folder);
                                return CheckboxListTile(
                                  value: !excluded,
                                  onChanged: (checked) =>
                                      widget.localMusic.setFolderExcluded(
                                    folder,
                                    checked != true,
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  secondary: Icon(
                                    excluded
                                        ? Icons.folder_off_rounded
                                        : Icons.folder_rounded,
                                    color: excluded
                                        ? colorScheme.outline
                                        : colorScheme.primary
                                            .withValues(alpha: .8),
                                  ),
                                  title: Text(
                                    folderDisplayName(folder),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: excluded
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$folder · ${entry.count} 首',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (excludedCount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                        child: Text(
                          '已排除 $excludedCount 个文件夹',
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 播放歌曲，队列语义与视图一致：
  /// - 列表模式：整个过滤后的列表
  /// - 分组模式：所属分组内的歌曲
  void _playSong(Song song, List<Song> queue) {
    widget.player.playSong(song, queue: queue);
  }

  void _toggleGroup(String folder) {
    setState(() {
      if (!_collapsedFolders.remove(folder)) {
        _collapsedFolders.add(folder);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StatusBarOverlay(
      brightness: Theme.of(context).brightness,
      child: LiquidGlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: const Text('本地音乐'),
            actions: [
              AnimatedBuilder(
                animation: widget.localMusic,
                builder: (context, _) {
                  if (widget.localMusic.isScanning) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (!Platform.isAndroid ||
                      !widget.localMusic.hasPermission) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    children: [
                      IconButton(
                        tooltip: '扫描目录设置',
                        onPressed: _showFolderFilterSheet,
                        icon: const Icon(Icons.rule_folder_rounded),
                      ),
                      IconButton(
                        tooltip: '重新扫描',
                        onPressed: () async {
                          await widget.localMusic.scanLocalMusic();
                          Toast.success('扫描完成');
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: AdaptiveContentPadding(
            child: AnimatedBuilder(
              animation: Listenable.merge(
                [widget.localMusic, widget.player],
              ),
              builder: (context, _) {
                // 非 Android 平台提示不支持
                if (!Platform.isAndroid) {
                  return _buildEmptyState(
                    context,
                    colorScheme,
                    icon: Icons.phone_android_rounded,
                    title: '仅支持 Android 设备',
                    subtitle: '本地音乐功能仅在 Android 平台上可用',
                  );
                }

                // 未授权状态
                if (!widget.localMusic.hasPermission) {
                  return _buildEmptyState(
                    context,
                    colorScheme,
                    icon: Icons.lock_outline_rounded,
                    title: '需要音频访问权限',
                    subtitle: '授予音频访问权限后，即可扫描并播放设备上的本地音乐',
                    action: FilledButton.icon(
                      onPressed: _requestPermission,
                      icon: const Icon(Icons.security_rounded),
                      label: const Text('授予权限'),
                    ),
                  );
                }

                final allSongs = widget.localMusic.songs;
                final filteredSongs = allSongs.where((song) {
                  final titleMatch =
                      song.title.toLowerCase().contains(_searchQuery);
                  final artistMatch =
                      song.artist.toLowerCase().contains(_searchQuery);
                  return titleMatch || artistMatch;
                }).toList();

                return Column(
                  children: [
                    // 歌曲数显示
                    if (allSongs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: LiquidGlassCard(
                          borderRadius: AppRadius.md,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enableTouchFlex: false,
                          child: Row(
                            children: [
                              Icon(
                                Icons.music_note_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '已扫描到本地音乐',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                _searchQuery.isEmpty
                                    ? '共 ${allSongs.length} 首'
                                    : '匹配 ${filteredSongs.length} / ${allSongs.length} 首',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 搜索栏 + 分组开关
                    if (allSongs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: LiquidGlassCard(
                          borderRadius: AppRadius.md,
                          padding: EdgeInsets.zero,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: '检索本地音乐...',
                                    prefixIcon:
                                        const Icon(Icons.search_rounded),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            onPressed: () =>
                                                _searchController.clear(),
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                            ),
                                          )
                                        : null,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 11,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    _grouped ? '切换为列表' : '按文件夹分组',
                                isSelected: _grouped,
                                onPressed: () {
                                  setState(() => _grouped = !_grouped);
                                },
                                icon: Icon(
                                  _grouped
                                      ? Icons.view_list_rounded
                                      : Icons.folder_rounded,
                                  color: _grouped
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                selectedIcon: Icon(
                                  Icons.view_list_rounded,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 歌曲列表 / 分组列表
                    Expanded(
                      child: widget.localMusic.isScanning
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : filteredSongs.isEmpty
                              ? _buildEmptyState(
                                  context,
                                  colorScheme,
                                  icon: Icons.library_music_rounded,
                                  title: allSongs.isEmpty
                                      ? '未找到本地音乐'
                                      : '没有检索到匹配的歌曲',
                                  subtitle: allSongs.isEmpty
                                      ? '设备上没有可播放的音频文件'
                                      : '尝试其他关键词搜索',
                                )
                              : _grouped
                                  ? _buildGroupedList(
                                      context,
                                      colorScheme,
                                      filteredSongs,
                                    )
                                  : _buildFlatList(
                                      context,
                                      colorScheme,
                                      filteredSongs,
                                    ),
                    ),
                  ],
                );
              },
            ),
          ),
          bottomNavigationBar: widget.auth == null
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MiniPlayer(
                      player: widget.player,
                      auth: widget.auth!,
                    ),
                  ),
                ),
          extendBody: true,
        ),
      ),
    );
  }

  /// 平铺列表：播放队列为当前过滤结果全集。
  Widget _buildFlatList(
    BuildContext context,
    ColorScheme colorScheme,
    List<Song> songs,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return _SongTile(
          key: ValueKey('flat-${song.id}'),
          song: song,
          isCurrent: widget.player.currentSong?.hash == song.hash,
          isPlaying: widget.player.isPlaying,
          colorScheme: colorScheme,
          onTap: () => _playSong(song, songs),
        );
      },
    );
  }

  /// 分组列表：分组头可折叠，点击歌曲时播放队列为所属分组。
  Widget _buildGroupedList(
    BuildContext context,
    ColorScheme colorScheme,
    List<Song> songs,
  ) {
    final groups = groupSongsByFolder(songs);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final collapsed = _collapsedFolders.contains(group.folder);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupHeader(
              group: group,
              collapsed: collapsed,
              colorScheme: colorScheme,
              onTap: () => _toggleGroup(group.folder),
              onPlayAll: () {
                if (group.songs.isEmpty) return;
                _playSong(group.songs.first, group.songs);
              },
            ),
            if (!collapsed)
              ...group.songs.map(
                (song) => _SongTile(
                  key: ValueKey('grp-${group.folder}-${song.id}'),
                  song: song,
                  isCurrent: widget.player.currentSong?.hash == song.hash,
                  isPlaying: widget.player.isPlaying,
                  colorScheme: colorScheme,
                  onTap: () => _playSong(song, group.songs),
                ),
              ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: .25),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: colorScheme.onSurfaceVariant.withValues(alpha: .5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// 单曲行，样式与改造前保持一致。
class _SongTile extends StatelessWidget {
  const _SongTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
    required this.colorScheme,
    required this.onTap,
  });

  final Song song;
  final bool isCurrent;
  final bool isPlaying;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          children: [
            Artwork(url: song.coverUrl, size: 44),
            if (isCurrent)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: NowPlayingBadge(
                    active: true,
                    playing: isPlaying,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent
              ? colorScheme.primary.withValues(alpha: .7)
              : colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// 分组头：点击折叠/展开，右侧按钮播放整组。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.collapsed,
    required this.colorScheme,
    required this.onTap,
    required this.onPlayAll,
  });

  final FolderGroup group;
  final bool collapsed;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onPlayAll;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.folder_rounded : Icons.folder_open_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (group.folder.isNotEmpty)
                    Text(
                      group.folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${group.songs.length} 首',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: IconButton(
                tooltip: '播放此文件夹',
                onPressed: onPlayAll,
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
            ),
            Icon(
              collapsed
                  ? Icons.chevron_right_rounded
                  : Icons.expand_more_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

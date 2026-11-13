import '../models/music_models.dart';

/// 本地音乐扫描的文件夹过滤工具。
///
/// 用户可将录音等目录加入排除列表，扫描结果中位于这些目录
/// （含子目录）下的歌曲将被过滤掉。所有比较均不区分大小写，
/// 并统一路径分隔符，避免大小写/分隔符差异导致匹配失败。
class FolderFilter {
  const FolderFilter._();

  /// 规范化文件夹路径：统一分隔符、去尾部 `/`、转小写。
  ///
  /// 空字符串或空白输入返回 `null`。
  static String? normalizeFolderPath(String? path) {
    if (path == null) return null;
    var normalized = path.trim().replaceAll('\\', '/');
    while (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.isEmpty || normalized == '/') return null;
    return normalized.toLowerCase();
  }

  /// 取文件所在父文件夹（已规范化）。无法解析时返回 `null`。
  static String? parentFolderOf(String? filePath) {
    if (filePath == null) return null;
    final normalized = filePath.trim().replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index <= 0) return null;
    return normalizeFolderPath(normalized.substring(0, index));
  }

  /// 判断 [filePath] 是否位于 [folder] 目录（含其子目录）下。
  ///
  /// [folder] 会先做规范化；两者比较不区分大小写。
  static bool isPathUnderFolder(String filePath, String folder) {
    final normalizedFolder = normalizeFolderPath(folder);
    if (normalizedFolder == null) return false;
    final parent = parentFolderOf(filePath);
    if (parent == null) return false;
    return parent == normalizedFolder || parent.startsWith('$normalizedFolder/');
  }

  /// 过滤掉位于 [excludedFolders] 目录（含子目录）下的歌曲。
  static List<Song> filterSongs(
    List<Song> songs,
    Iterable<String> excludedFolders,
  ) {
    final normalized = excludedFolders
        .map(normalizeFolderPath)
        .whereType<String>()
        .toSet();
    if (normalized.isEmpty) return List<Song>.of(songs);

    return songs.where((song) {
      final parent = parentFolderOf(song.hash);
      return parent == null ||
          (!normalized.contains(parent) &&
              !normalized.any((folder) => parent.startsWith('$folder/')));
    }).toList();
  }

  /// 统计各父文件夹下的歌曲数量（按数量降序，供排除设置界面展示）。
  static List<({String folder, int count})> folderCounts(List<Song> songs) {
    final counts = <String, int>{};
    for (final song in songs) {
      final parent = parentFolderOf(song.hash);
      if (parent == null) continue;
      counts[parent] = (counts[parent] ?? 0) + 1;
    }
    final result = counts.entries
        .map((entry) => (folder: entry.key, count: entry.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.folder.compareTo(b.folder);
      });
    return result;
  }
}

/// 文件夹分组的展示模型。
///
/// [folder] 为规范化后的父目录绝对路径，`''` 表示无法解析父目录的
/// 「其他」分组；[displayName] 为界面展示名；[songs] 为该目录下的歌曲，
/// 顺序与输入列表保持一致。
class FolderGroup {
  const FolderGroup({
    required this.folder,
    required this.displayName,
    required this.songs,
  });

  final String folder;
  final String displayName;
  final List<Song> songs;

  /// 该分组的播放队列哈希列表（用于调试与去重判断）。
  List<String> get songHashes => [for (final s in songs) s.hash];

  /// 分组内是否包含 [hash] 对应的歌曲。
  bool containsHash(String hash) => songs.any((s) => s.hash == hash);
}

/// 取文件夹显示名：优先末级目录名，顶层存储目录（末级为 `0`）显示完整路径。
///
/// [folder] 为规范化路径；无法解析时原样返回。
String folderDisplayName(String folder) {
  final segments = folder.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return folder;
  if (segments.length == 3 &&
      segments[0] == 'storage' &&
      segments[1] == 'emulated' &&
      segments[2] == '0') {
    return folder;
  }
  final last = segments.last;
  if (last == '0' || last == 'storage') return folder;
  return last;
}

bool _isStorageRootFolder(String folder) {
  final segments = folder.split('/').where((s) => s.isNotEmpty).toList();
  return segments.length == 3 &&
      segments[0] == 'storage' &&
      segments[1] == 'emulated' &&
      segments[2] == '0';
}

/// 按父文件夹对 [songs] 分组。
///
/// 排序规则：先按展示名不区分大小写升序；「其他」分组（无法解析父目录）
/// 固定排在最后。顶层存储目录也固定排在最后，避免 `/storage/emulated/0`
/// 因 ASCII 排序而被误排到首位。分组内部的歌曲顺序保持输入顺序。
List<FolderGroup> groupSongsByFolder(List<Song> songs) {
  final buckets = <String, List<Song>>{};
  for (final song in songs) {
    final parent = FolderFilter.parentFolderOf(song.hash) ?? '';
    buckets.putIfAbsent(parent, () => <Song>[]).add(song);
  }
  final groups = <FolderGroup>[
    for (final entry in buckets.entries)
      FolderGroup(
        folder: entry.key,
        displayName:
            entry.key.isEmpty ? '其他' : folderDisplayName(entry.key),
        songs: entry.value,
      ),
  ];
  groups.sort((a, b) {
    if (a.folder.isEmpty) return 1;
    if (b.folder.isEmpty) return -1;
    final aRoot = _isStorageRootFolder(a.folder);
    final bRoot = _isStorageRootFolder(b.folder);
    if (aRoot && !bRoot) return 1;
    if (!aRoot && bRoot) return -1;
    return a.displayName
        .toLowerCase()
        .compareTo(b.displayName.toLowerCase());
  });
  return groups;
}

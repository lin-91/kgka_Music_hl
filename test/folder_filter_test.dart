import 'package:flutter_test/flutter_test.dart';
import 'package:kgka_music_hl/core/folder_filter.dart';
import 'package:kgka_music_hl/models/music_models.dart';

Song _localSong(String path) => Song(
      id: path,
      title: '歌曲',
      artist: '艺人',
      hash: path,
      source: SongSource.local,
    );

void main() {
  _folderGroupTests();
  group('normalizeFolderPath', () {
    test('统一分隔符并转小写、去尾部斜杠', () {
      expect(
        FolderFilter.normalizeFolderPath(r'/storage/emulated/0/Recordings/'),
        '/storage/emulated/0/recordings',
      );
      expect(
        FolderFilter.normalizeFolderPath(r'\Storage\Emulated\0\Records'),
        '/storage/emulated/0/records',
      );
    });

    test('空值与根目录返回 null', () {
      expect(FolderFilter.normalizeFolderPath(null), isNull);
      expect(FolderFilter.normalizeFolderPath('  '), isNull);
      expect(FolderFilter.normalizeFolderPath('/'), isNull);
    });
  });

  group('parentFolderOf', () {
    test('返回规范化父目录', () {
      expect(
        FolderFilter.parentFolderOf('/storage/emulated/0/Recordings/a.m4a'),
        '/storage/emulated/0/recordings',
      );
      expect(
        FolderFilter.parentFolderOf(r'\storage\emulated\0\Music\b.mp3'),
        '/storage/emulated/0/music',
      );
    });

    test('无法解析时返回 null', () {
      expect(FolderFilter.parentFolderOf(null), isNull);
      expect(FolderFilter.parentFolderOf(''), isNull);
      expect(FolderFilter.parentFolderOf('relative.mp3'), isNull);
    });
  });

  group('isPathUnderFolder', () {
    test('命中目录本身与子目录（不区分大小写）', () {
      const folder = '/storage/emulated/0/Recordings';
      expect(
        FolderFilter.isPathUnderFolder(
          '/storage/emulated/0/Recordings/a.m4a',
          folder,
        ),
        isTrue,
      );
      expect(
        FolderFilter.isPathUnderFolder(
          '/storage/emulated/0/recordings/sub/b.m4a',
          folder,
        ),
        isTrue,
      );
      expect(
        FolderFilter.isPathUnderFolder(
          '/storage/emulated/0/Music/c.mp3',
          folder,
        ),
        isFalse,
      );
    });

    test('前缀匹配不会误伤相似路径', () {
      expect(
        FolderFilter.isPathUnderFolder(
          '/storage/emulated/0/RecordingsOld/a.m4a',
          '/storage/emulated/0/Recordings',
        ),
        isFalse,
      );
    });
  });

  group('filterSongs', () {
    test('排除目录下的歌曲被过滤，其余保留', () {
      final songs = [
        _localSong('/storage/emulated/0/Recordings/a.m4a'),
        _localSong('/storage/emulated/0/Recordings/sub/b.m4a'),
        _localSong('/storage/emulated/0/Music/c.mp3'),
      ];
      final filtered = FolderFilter.filterSongs(
        songs,
        ['/storage/emulated/0/Recordings'],
      );
      expect(filtered.map((s) => s.hash), ['/storage/emulated/0/Music/c.mp3']);
    });

    test('无排除项时返回完整列表', () {
      final songs = [_localSong('/a/b/c.mp3')];
      final filtered = FolderFilter.filterSongs(songs, const []);
      expect(filtered, hasLength(1));
    });

    test('路径解析失败的歌曲保留（不过度过滤）', () {
      final songs = [_localSong('no-parent.mp3')];
      final filtered = FolderFilter.filterSongs(
        songs,
        ['/storage/emulated/0/Recordings'],
      );
      expect(filtered, hasLength(1));
    });
  });

  group('folderCounts', () {
    test('按父目录统计并按数量降序', () {
      final songs = [
        _localSong('/storage/emulated/0/Music/a.mp3'),
        _localSong('/storage/emulated/0/Music/b.mp3'),
        _localSong('/storage/emulated/0/Recordings/c.m4a'),
      ];
      final counts = FolderFilter.folderCounts(songs);
      expect(counts, hasLength(2));
      expect(counts.first.folder, '/storage/emulated/0/music');
      expect(counts.first.count, 2);
      expect(counts.last.folder, '/storage/emulated/0/recordings');
      expect(counts.last.count, 1);
    });
  });
}

// ==== 文件夹分组与播放队列语义 ====

Song _songWithPath(String path) => Song(
      id: path,
      title: path.split('/').last,
      artist: '艺人',
      hash: path,
      source: SongSource.local,
    );

void _folderGroupTests() {
  group('groupSongsByFolder', () {
    test('按父目录分组，组内保持输入顺序', () {
      final songs = [
        _songWithPath('/storage/emulated/0/Music/周杰伦/晴天.mp3'),
        _songWithPath('/storage/emulated/0/Download/新歌A.mp3'),
        _songWithPath('/storage/emulated/0/Music/周杰伦/七里香.mp3'),
      ];
      final groups = groupSongsByFolder(songs);
      expect(groups, hasLength(2));
      final music = groups.firstWhere(
        (g) => g.folder == '/storage/emulated/0/music/周杰伦',
      );
      expect(music.displayName, '周杰伦');
      expect(music.songs.map((s) => s.hash), [
        '/storage/emulated/0/Music/周杰伦/晴天.mp3',
        '/storage/emulated/0/Music/周杰伦/七里香.mp3',
      ]);
    });

    test('无法解析父目录的歌曲归入「其他」并排在最后', () {
      final songs = [
        _songWithPath('no-parent.mp3'),
        _songWithPath('/storage/emulated/0/Download/新歌B.mp3'),
      ];
      final groups = groupSongsByFolder(songs);
      expect(groups, hasLength(2));
      expect(groups.last.folder, '');
      expect(groups.last.displayName, '其他');
      expect(groups.last.songs.single.hash, 'no-parent.mp3');
    });

    test('分组播放队列仅包含该文件夹下的歌曲', () {
      final songs = [
        _songWithPath('/storage/emulated/0/Music/陈奕迅/浮夸.flac'),
        _songWithPath('/storage/emulated/0/Download/新歌A.mp3'),
        _songWithPath('/storage/emulated/0/Music/陈奕迅/十年.flac'),
      ];
      final groups = groupSongsByFolder(songs);
      final eason = groups.firstWhere((g) => g.displayName == '陈奕迅');
      expect(eason.songHashes, [
        '/storage/emulated/0/Music/陈奕迅/浮夸.flac',
        '/storage/emulated/0/Music/陈奕迅/十年.flac',
      ]);
      expect(eason.containsHash('/storage/emulated/0/Download/新歌A.mp3'),
          isFalse);
    });

    test('展示名排序不区分大小写，顶层存储目录回退完整路径', () {
      final songs = [
        _songWithPath('/storage/emulated/0/Music/b/a.mp3'),
        _songWithPath('/storage/emulated/0/Music/A/c.mp3'),
        _songWithPath('/storage/emulated/0/x.mp3'),
      ];
      final groups = groupSongsByFolder(songs);
      final names = groups.map((g) => g.displayName).toList();
      expect(names.first.toLowerCase(), 'a');
      expect(names.last, '/storage/emulated/0');
    });
  });
}

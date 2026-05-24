import 'package:api/api.dart';

class JellyfinUtils {
  static Future<Movie?> findMovieByFileId(String? fileId) async {
    if (fileId == null) return null;
    final result = await Api.movieQueryAll(const MediaSearchQuery(limit: 10000));
    try {
      return result.data.firstWhere((m) => m.fileId == fileId);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Library>> getJellyfinLibraries() async {
    final allLibraries = await Api.libraryQueryAll(LibraryType.movie);
    return allLibraries.where((lib) =>
      lib.driverType == DriverType.jellyfin || lib.driverType == DriverType.emby
    ).toList();
  }

  static Future<List<DriverFile>> getRootFolders(int driverId) async {
    return Api.fileList(driverId, '/');
  }
}

import 'dart:async';

import 'package:api/api.dart';
import 'package:flutter/material.dart';

import '../../components/future_builder_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/jellyfin_utils.dart';
import '../../utils/utils.dart';
import '../components/image_card.dart';
import '../detail/movie.dart';
import '../library.dart';
import '../settings/settings_player_history.dart';
import 'components/carousel.dart';
import 'components/channel.dart';
import 'components/folder_badge.dart';
import 'components/folder_breadcrumb.dart';
import 'components/jellyfin_folder_grid_channel.dart';
import 'components/media_scaffold.dart';
import 'search.dart';

class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key});

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  final _backdrop = ValueNotifier<String?>(null);
  List<({String id, String name})> _breadcrumbPaths = [];
  int? _currentDriverId;
  String? _currentParentId;
  bool _isBrowsingFolders = false;

  @override
  void initState() {
    super.initState();
    _checkJellyfinLibraries();
  }

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  Future<void> _checkJellyfinLibraries() async {
    final libs = await JellyfinUtils.getJellyfinLibraries();
    if (!mounted) return;
    setState(() {
      if (libs.isNotEmpty) {
        _currentDriverId = libs.first.driverId;
        _isBrowsingFolders = true;
        _breadcrumbPaths = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: MediaScaffold(
        backdrop: _backdrop,
        slivers: [
          FutureBuilderSliverHandler(
            future: Api.movieRecommendation(),
            loadingBuilder: (context, snapshot) => const CarouselPlaceholder(),
            builder: (context, snapshot) {
              return MediaCarousel(
                count: snapshot.requireData.length,
                onChanged: (index) {
                  _backdrop.value = snapshot.requireData[index].backdrop;
                },
                noDataBuilder:
                    (context) => FilledButton(
                      child: Text(AppLocalizations.of(context)!.settingsItemMovie),
                      onPressed: () => navigateTo(context, const LibraryManage(type: LibraryType.movie)),
                    ),
                itemBuilder: (BuildContext context, int index) {
                  final item = snapshot.requireData[index];
                  return CarouselItem(item: item, onPressed: () => _onMediaTap(context, item.id));
                },
              );
            },
          ),
          MediaChannel(
            label: AppLocalizations.of(context)!.watchNow,
            height: 262,
            future: Api.movieNextToPlayQueryAll(),
            more: IconButton(
              style: IconButton.styleFrom(
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                padding: EdgeInsets.zero,
              ),
              onPressed: () => navigateTo(context, const SystemSettingsPlayerHistory()),
              icon: const Icon(Icons.chevron_right),
            ),
            builder: _buildRecentMediaCard,
            loadingBuilder: (context) => const ImageCardPlaceholder(width: 120, height: 180),
          ),
          MediaChannel(
            label: AppLocalizations.of(context)!.tagFavorite,
            more: IconButton(
              style: IconButton.styleFrom(
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                padding: EdgeInsets.zero,
              ),
              onPressed: () => navigateTo(context, const SearchPage(filterType: [FilterType.favorite], activeTab: 1)),
              icon: const Icon(Icons.chevron_right),
            ),
            future: Api.movieQueryAll(
              const MediaSearchQuery(
                sort: SortConfig(type: SortType.createAt, direction: SortDirection.desc, filter: FilterType.favorite),
                limit: 8,
              ),
            ).then((data) => data.data),
            height: 262,
            builder: (context, item, index) => _buildMediaCard(context, item, width: 120, height: 180),
            loadingBuilder: (context) => const ImageCardPlaceholder(width: 120, height: 180),
          ),
          MediaChannel(
            label: AppLocalizations.of(context)!.tagNewAdd,
            height: 262,
            future: Api.movieQueryAll(
              const MediaSearchQuery(
                sort: SortConfig(type: SortType.createAt, direction: SortDirection.desc),
                limit: 8,
              ),
            ).then((data) => data.data),
            builder: (context, item, index) => _buildMediaCard(context, item, width: 120, height: 180),
            loadingBuilder: (context) => const ImageCardPlaceholder(width: 120, height: 180),
          ),
          MediaChannel(
            label: AppLocalizations.of(context)!.tagNewRelease,
            height: 262,
            future: Api.movieQueryAll(
              const MediaSearchQuery(
                sort: SortConfig(type: SortType.createAt, direction: SortDirection.desc),
                limit: 8,
              ),
            ).then((data) => data.data),
            builder: (context, item, index) => _buildMediaCard(context, item, width: 120, height: 180),
            loadingBuilder: (context) => const ImageCardPlaceholder(width: 120, height: 180),
          ),
          _buildAllSection(),
        ],
      ),
    );
  }

  Widget _buildAllSection() {
    if (_isBrowsingFolders && _currentDriverId != null) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: FolderBreadcrumb(
              paths: _breadcrumbPaths,
              onPathTap: _onBreadcrumbTap,
            ),
          ),
          JellyfinFolderGridChannel(
            label: AppLocalizations.of(context)!.tagAll,
            driverId: _currentDriverId!,
            parentId: _currentParentId ?? '/',
            onFolderTap: _onFolderTap,
            onMovieTap: (movie) => _onMediaTap(context, movie.id, movie),
            itemBuilder: (context, file, movie) => _buildFolderItem(context, file, movie),
          ),
        ],
      );
    }

    return MediaGridChannel(
      label: AppLocalizations.of(context)!.tagAll,
      onQuery: (index) => Api.movieQueryAll(MediaSearchQuery(limit: 30, offset: 30 * index)),
      itemBuilder: (context, item, index) => _buildMediaCard(context, item),
    );
  }

  Widget _buildFolderItem(BuildContext context, DriverFile file, Movie? movie) {
    if (file.type == FileType.folder) {
      return GestureDetector(
        onTap: () => _onFolderTap(file.id, file.name),
        child: Stack(
          children: [
            ImageCard(
              null,
              title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const FolderBadge(),
          ],
        ),
      );
    }

    if (movie != null) {
      return _buildMediaCard(context, movie);
    }

    return ImageCard(
      null,
      title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () {
        // Play raw file without metadata
      },
    );
  }

  void _onFolderTap(String folderId, String folderName) {
    setState(() {
      _breadcrumbPaths.add((id: folderId, name: folderName));
      _currentParentId = folderId;
    });
  }

  void _onBreadcrumbTap(String folderId) {
    setState(() {
      final index = _breadcrumbPaths.indexWhere((p) => p.id == folderId);
      if (index >= 0) {
        _breadcrumbPaths.removeRange(index + 1, _breadcrumbPaths.length);
        _currentParentId = folderId == '/' ? null : folderId;
      } else if (folderId == '/') {
        _breadcrumbPaths.clear();
        _currentParentId = null;
      }
    });
  }

  Widget _buildRecentMediaCard(BuildContext context, Movie item, int index) {
    return ImageCard(
      item.poster,
      width: 120,
      height: 180,
      title: Text(item.displayRecentTitle()),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (item.lastPlayedTime != null)
            Text(
              AppLocalizations.of(context)!.timeAgo(item.lastPlayedTime!.fromNow().fromNowFormat(context)),
              style: Theme.of(context).textTheme.labelSmall,
            )
          else
            const Spacer(),
          if (item.duration != null && item.duration != Duration.zero && item.lastPlayedPosition != null)
            Text('${(item.lastPlayedPosition!.inSeconds / item.duration!.inSeconds * 100).toStringAsFixed(1)}%'),
        ],
      ),
      floating:
          item.duration != null && item.duration != Duration.zero && item.lastPlayedPosition != null
              ? Align(
                alignment: const Alignment(0, 0.95),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: LinearProgressIndicator(
                    value: item.lastPlayedPosition!.inSeconds / item.duration!.inSeconds,
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(3),
                    minHeight: 3,
                  ),
                ),
              )
              : null,
      onTap: () => _onMediaTap(context, item.id, item),
    );
  }

  Widget _buildMediaCard(BuildContext context, Movie item, {double? width, double? height}) {
    return ImageCard(
      item.poster,
      width: width,
      height: height,
      title: Text(item.displayRecentTitle()),
      subtitle: Text(item.releaseDate?.format() ?? ''),
      floating: MediaBadges(item: item),
      onTap: () => _onMediaTap(context, item.id, item),
    );
  }

  Future<void> _onMediaTap(BuildContext context, dynamic id, [Movie? item]) async {
    await navigateTo(context, MovieDetail(id, initialData: item));
    if (context.mounted) setState(() {});
  }
}

import 'package:api/api.dart';
import 'package:flutter/material.dart';

import '../../components/no_data.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../utils/jellyfin_utils.dart';
import '../../utils/utils.dart';
import '../components/filled_button.dart';
import '../components/future_builder_handler.dart';
import '../detail/movie.dart';
import '../media/components/carousel.dart';
import '../settings/settings_library.dart';
import '../utils/player.dart';
import '../utils/utils.dart';
import 'components/folder_badge.dart';
import 'components/folder_breadcrumb.dart';
import 'components/jellyfin_folder_grid_channel.dart';
import 'components/media_grid_item.dart';
import 'mixins/channel.dart';

class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key, required this.endDrawerNavigatorKey});

  final GlobalKey<NavigatorState> endDrawerNavigatorKey;

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  final _backdrop = ValueNotifier<String?>(null);
  final _carouselIndex = ValueNotifier<int?>(null);
  final _showBlur = ValueNotifier(false);
  final _scrollController = ScrollController();
  late final halfHeight = MediaQuery.of(context).size.height / 2;

  List<({String id, String name})> _breadcrumbPaths = [];
  int? _currentDriverId;
  String? _currentParentId;
  bool _isBrowsingFolders = false;

  @override
  void initState() {
    _scrollController.addListener(_scrollListener);
    super.initState();
    _checkJellyfinLibraries();
  }

  @override
  void dispose() {
    _backdrop.dispose();
    _carouselIndex.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 2,
          child: ListenableBuilder(
            listenable: Listenable.merge([_backdrop, _showBlur]),
            builder: (context, _) => CarouselBackground(src: _backdrop.value),
          ),
        ),
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            FutureBuilderSliverHandler(
              future: Api.movieRecommendation(),
              loadingBuilder: (context, _) => const AspectRatio(aspectRatio: 32 / 15, child: CarouselPlaceholder()),
              builder: (context, snapshot) {
                Future.microtask(() {
                  if (snapshot.requireData.isNotEmpty) {
                    _backdrop.value = snapshot.requireData[0].backdrop;
                  } else {
                    _backdrop.value = null;
                  }
                });
                return SliverToBoxAdapter(
                  child: AspectRatio(
                    aspectRatio: 32 / 15,
                    child:
                        snapshot.requireData.isNotEmpty
                            ? ListenableBuilder(
                              listenable: _carouselIndex,
                              builder: (context, _) {
                                final item =
                                    snapshot.requireData.elementAtOrNull(_carouselIndex.value ?? 0) ??
                                    snapshot.requireData.first;
                                return Carousel(
                                  key: ValueKey(snapshot.requireData.length),
                                  index: _carouselIndex.value ?? 0,
                                  len: snapshot.requireData.length,
                                  onChange: (index) {
                                    _backdrop.value = snapshot.requireData[index].backdrop;
                                    _carouselIndex.value = index;
                                  },
                                  child: CarouselItem(
                                    key: ValueKey(item.id),
                                    item: item,
                                    onPressed: () async {
                                      await toPlayer(
                                        context,
                                        Future.microtask(() async {
                                          final movie = await Api.movieQueryById(item.id);
                                          return ([FromMedia.fromMovie(movie)], 0);
                                        }),
                                        theme: item.themeColor,
                                      );
                                      setState(() {});
                                    },
                                  ),
                                );
                              },
                            )
                            : Center(
                              child: NoData(
                                action: TVFilledButton(
                                  autofocus: true,
                                  child: Text(AppLocalizations.of(context)!.settingsItemMovie),
                                  onPressed: () async {
                                    Scaffold.of(context).openEndDrawer();
                                    await Future.delayed(const Duration(milliseconds: 100));
                                    if (context.mounted) {
                                      navigateToSlideLeft(
                                        widget.endDrawerNavigatorKey.currentContext!,
                                        LibraryManage(
                                          title: AppLocalizations.of(context)!.settingsItemMovie,
                                          type: LibraryType.movie,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                  ),
                );
              },
            ),
            MediaChannel(
              itemExtent: 176,
              label: AppLocalizations.of(context)!.watchNow,
              future: Api.movieNextToPlayQueryAll(),
              height: 340,
              builder: (context, item) => _buildRecentMediaItem(context, item, width: 160, height: 160 / 0.67),
              loadingBuilder:
                  (context) => MediaGridItem(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    imageWidth: 160,
                    imageHeight: 160 / 0.67,
                    title: Container(
                      width: 100,
                      height: 18,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                    ),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        ),
                        Container(
                          width: 20,
                          height: 12,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                  ),
            ),
            MediaChannel(
              itemExtent: 176,
              label: AppLocalizations.of(context)!.tagFavorite,
              future: Api.movieQueryAll(
                const MediaSearchQuery(
                  sort: SortConfig(type: SortType.createAt, direction: SortDirection.desc, filter: FilterType.favorite),
                  limit: 8,
                ),
              ).then((data) => data.data),
              height: 340,
              builder: (context, item) => _buildMediaItem(context, item, width: 160, height: 160 / 0.67),
            ),
            MediaChannel(
              itemExtent: 176,
              label: AppLocalizations.of(context)!.tagNewAdd,
              future: Api.movieQueryAll(
                const MediaSearchQuery(
                  sort: SortConfig(type: SortType.createAt, direction: SortDirection.desc),
                  limit: 8,
                ),
              ).then((data) => data.data),
              height: 340,
              builder: (context, item) => _buildMediaItem(context, item, width: 160, height: 160 / 0.67),
            ),
            MediaChannel(
              itemExtent: 176,
              label: AppLocalizations.of(context)!.tagNewRelease,
              future: Api.movieQueryAll(
                const MediaSearchQuery(
                  sort: SortConfig(type: SortType.airDate, direction: SortDirection.desc),
                  limit: 8,
                ),
              ).then((data) => data.data),
              height: 340,
              builder: (context, item) => _buildMediaItem(context, item, width: 160, height: 160 / 0.67),
            ),
            _buildAllSection(),
          ],
        ),
      ],
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
            onMovieTap: _onMediaTap,
            itemBuilder: (context, file, movie) => _buildFolderItem(context, file, movie),
          ),
        ],
      );
    }

    return MediaGridChannel(
      label: AppLocalizations.of(context)!.tagAll,
      onQuery:
          (index) => Api.movieQueryAll(
            MediaSearchQuery(
              limit: 30,
              offset: 30 * index,
              sort: const SortConfig(type: SortType.title, direction: SortDirection.asc),
            ),
          ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 196,
        childAspectRatio: 0.5,
        mainAxisSpacing: 36,
        mainAxisExtent: 300,
      ),
      itemBuilder: (context, item, index) => _buildMediaItem(context, item, width: 160, height: 160 / 0.67),
    );
  }

  Widget _buildFolderItem(BuildContext context, DriverFile file, Movie? movie) {
    if (file.type == FileType.folder) {
      return GestureDetector(
        onTap: () => _onFolderTap(file.id, file.name),
        child: Stack(
          children: [
            MediaGridItem(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const FolderBadge(),
          ],
        ),
      );
    }

    if (movie != null) {
      return _buildMediaItem(context, movie, width: 160, height: 160 / 0.67);
    }

    return MediaGridItem(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildRecentMediaItem(BuildContext context, Movie item, {double? width, double? height}) {
    return MediaGridItem(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      imageWidth: width,
      imageHeight: height,
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
          if (item.duration != null && item.lastPlayedTime != null)
            Text('${(item.lastPlayedPosition!.inSeconds / item.duration!.inSeconds * 100).toStringAsFixed(1)}%'),
        ],
      ),
      imageUrl: item.poster,
      floating:
          item.duration != null && item.duration != Duration.zero && item.lastPlayedTime != null
              ? SizedBox(
                width: 160,
                child: Align(
                  alignment: const Alignment(0, 0.47),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: LinearProgressIndicator(
                      value: item.lastPlayedPosition!.inSeconds / item.duration!.inSeconds,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      minHeight: 3,
                    ),
                  ),
                ),
              )
              : null,
      onTap: () async {
        await toPlayer(
          context,
          Future.microtask(() async {
            final movie = await Api.movieQueryById(item.id);
            return ([FromMedia.fromMovie(movie)], 0);
          }),
          theme: item.themeColor,
        );
        setState(() {});
      },
    );
  }

  Widget _buildMediaItem(BuildContext context, Movie item, {double? width, double? height}) {
    return MediaGridItem(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      imageWidth: width,
      imageHeight: height,
      imageUrl: item.poster,
      title: Text(item.displayTitle()),
      subtitle: Text(item.releaseDate?.format() ?? ''),
      onTap: () => _onMediaTap(item),
    );
  }

  Future<void> _onMediaTap(Movie item) async {
    final flag = await navigateTo<bool>(context, MovieDetail(initialData: item));
    if ((flag ?? false) && mounted) {
      setState(() {});
    }
  }

  void _scrollListener() {
    _showBlur.value = _scrollController.offset > halfHeight;
  }
}

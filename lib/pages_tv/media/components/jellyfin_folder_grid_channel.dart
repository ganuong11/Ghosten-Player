import 'package:api/api.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../components/error_message.dart';
import '../../../components/no_data.dart';
import '../../components/loading.dart';
import 'folder_badge.dart';

class JellyfinFolderGridChannel extends StatefulWidget {
  const JellyfinFolderGridChannel({
    super.key,
    required this.label,
    required this.driverId,
    required this.parentId,
    required this.onFolderTap,
    required this.onMovieTap,
    required this.itemBuilder,
  });

  final String label;
  final int driverId;
  final String parentId;
  final void Function(String folderId, String folderName) onFolderTap;
  final void Function(Movie movie) onMovieTap;
  final Widget Function(BuildContext context, DriverFile item, Movie? movie) itemBuilder;

  @override
  State<JellyfinFolderGridChannel> createState() => _JellyfinFolderGridChannelState();
}

class _JellyfinFolderGridChannelState extends State<JellyfinFolderGridChannel> {
  PagingState<int, DriverFile> _state = PagingState();
  List<Movie> _moviesCache = [];
  int _currentOffset = 0;
  static const int _pageSize = 30;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant JellyfinFolderGridChannel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentId != widget.parentId || oldWidget.driverId != widget.driverId) {
      _resetAndReload();
    }
  }

  void _resetAndReload() {
    setState(() {
      _state = PagingState();
      _currentOffset = 0;
      _hasMorePages = true;
      _moviesCache = [];
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _state = _state.copyWith(isLoading: true, error: null));

    try {
      final results = await Future.wait([
        Api.fileList(widget.driverId, widget.parentId),
        Api.movieQueryAll(const MediaSearchQuery(limit: 10000)),
      ]);

      final files = results[0] as List<DriverFile>;
      _moviesCache = (results[1] as PageData<Movie>).data;

      final folders = files.where((f) => f.type == FileType.folder).toList();
      final videoFiles = files.where((f) =>
        f.type == FileType.file && f.category == FileCategory.video
      ).toList();

      final allItems = [...folders, ...videoFiles];
      _hasMorePages = allItems.length >= _pageSize;

      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          pages: [allItems],
          keys: [0],
          hasNextPage: _hasMorePages,
          isLoading: false,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(error: error, isLoading: false);
      });
    }
  }

  Future<void> _fetchNextPage() async {
    if (_state.isLoading || !_hasMorePages) return;

    setState(() => _state = _state.copyWith(isLoading: true, error: null));

    try {
      _currentOffset += _pageSize;
      final files = await Api.fileList(widget.driverId, widget.parentId);

      final folders = files.where((f) => f.type == FileType.folder).toList();
      final videoFiles = files.where((f) =>
        f.type == FileType.file && f.category == FileCategory.video
      ).skip(_currentOffset).toList();

      final allItems = [...folders, ...videoFiles];
      _hasMorePages = allItems.length >= _pageSize;

      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          pages: [...?_state.pages, allItems],
          keys: [...?_state.keys, _currentOffset],
          hasNextPage: _hasMorePages,
          isLoading: false,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(error: error, isLoading: false);
      });
    }
  }

  Movie? _findMovieByFileId(String? fileId) {
    if (fileId == null) return null;
    try {
      return _moviesCache.firstWhere((m) => m.fileId == fileId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (_state.isLoading && (_state.pages?.isEmpty ?? true))
          const SliverFillRemaining(child: Loading())
        else if (_state.error != null)
          SliverFillRemaining(child: ErrorMessage(error: _state.error))
        else if (_state.pages?.isEmpty ?? true)
          const SliverFillRemaining(child: NoData())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: PagedSliverGrid(
              builderDelegate: PagedChildBuilderDelegate<DriverFile>(
                itemBuilder: (context, item, index) {
                  final movie = _findMovieByFileId(item.fileId);
                  return Stack(
                    children: [
                      widget.itemBuilder(context, item, movie),
                      if (item.type == FileType.folder) const FolderBadge(),
                    ],
                  );
                },
                noMoreItemsIndicatorBuilder: (context) => const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Column(
                    spacing: 16,
                    children: [
                      FractionallySizedBox(widthFactor: 0.5, child: Divider()),
                      Text('THE END', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                firstPageProgressIndicatorBuilder: (context) => const Loading(),
                newPageProgressIndicatorBuilder: (context) => const Padding(padding: EdgeInsets.only(top: 16), child: Loading()),
              ),
              showNewPageProgressIndicatorAsGridChild: false,
              showNoMoreItemsIndicatorAsGridChild: false,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 196,
                childAspectRatio: 0.5,
                mainAxisSpacing: 36,
                crossAxisSpacing: 16,
                mainAxisExtent: 300,
              ),
              fetchNextPage: _fetchNextPage,
              state: _state,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Enterprise Pagination Models & Utilities
// ─────────────────────────────────────────────

class PaginationParams {
  final int page;
  final int pageSize;
  final String? cursor;
  final String? searchQuery;
  final String? sortBy;
  final bool ascending;

  const PaginationParams({
    this.page = 1,
    this.pageSize = 20,
    this.cursor,
    this.searchQuery,
    this.sortBy,
    this.ascending = false,
  });

  int get offset => (page - 1) * pageSize;
  int get rangeFrom => offset;
  int get rangeTo => offset + pageSize - 1;

  PaginationParams nextPage() => PaginationParams(
        page: page + 1,
        pageSize: pageSize,
        cursor: cursor,
        searchQuery: searchQuery,
        sortBy: sortBy,
        ascending: ascending,
      );

  PaginationParams copyWith({
    int? page,
    int? pageSize,
    String? cursor,
    String? searchQuery,
    String? sortBy,
    bool? ascending,
  }) {
    return PaginationParams(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      cursor: cursor ?? this.cursor,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}

class PaginatedList<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasMore;
  final String? nextCursor;

  const PaginatedList({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasMore,
    this.nextCursor,
  });

  factory PaginatedList.empty() {
    return const PaginatedList(
      items: [],
      page: 1,
      pageSize: 20,
      totalCount: 0,
      hasMore: false,
    );
  }

  PaginatedList<T> append(PaginatedList<T> nextPage) {
    return PaginatedList<T>(
      items: [...items, ...nextPage.items],
      page: nextPage.page,
      pageSize: pageSize,
      totalCount: nextPage.totalCount > 0 ? nextPage.totalCount : totalCount,
      hasMore: nextPage.hasMore,
      nextCursor: nextPage.nextCursor,
    );
  }
}

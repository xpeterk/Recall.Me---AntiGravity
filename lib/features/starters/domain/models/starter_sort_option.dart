enum StarterSortOption {
  newestFirst,
  oldestFirst,
  relevance,
}

extension StarterSortOptionExtension on StarterSortOption {
  String get label {
    switch (this) {
      case StarterSortOption.newestFirst:
        return 'Newest first';
      case StarterSortOption.oldestFirst:
        return 'Oldest first';
      case StarterSortOption.relevance:
        return 'Relevance';
    }
  }

  String get shortLabel {
    switch (this) {
      case StarterSortOption.newestFirst:
        return 'Newest';
      case StarterSortOption.oldestFirst:
        return 'Oldest';
      case StarterSortOption.relevance:
        return 'Relevance';
    }
  }
}

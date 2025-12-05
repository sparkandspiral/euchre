const klondikeDailySeeds = <int>[
  5,
  6,
  7,
  8,
  10,
  12,
  13,
  14,
  15,
  23,
  27,
  30,
  33,
  34,
  35,
  44,
  46,
  47,
  50,
  54,
];

int seedForDate(DateTime date, List<int> seeds) {
  if (seeds.isEmpty) {
    throw StateError('No seeds configured');
  }

  final epoch = DateTime.utc(2025, 1, 1);
  final days = date.toUtc().difference(epoch).inDays;
  final index = (days % seeds.length + seeds.length) % seeds.length;
  return seeds[index];
}


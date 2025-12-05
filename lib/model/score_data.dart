class ScoreData {
  final int rank;
  final int rawScore;
  final String displayName;
  final int userId;

  const ScoreData({
    required this.rank,
    required this.rawScore,
    required this.displayName,
    required this.userId,
  });

  Duration get duration => Duration(milliseconds: rawScore * 10);
}



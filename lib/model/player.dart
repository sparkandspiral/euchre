enum PlayerPosition {
  south,
  west,
  north,
  east;

  PlayerPosition get next => PlayerPosition.values[(index + 1) % 4];
  PlayerPosition get partner => PlayerPosition.values[(index + 2) % 4];

  Team get team => (this == PlayerPosition.south || this == PlayerPosition.north)
      ? Team.playerTeam
      : Team.opponentTeam;

  bool get isHuman => this == PlayerPosition.south;

  String get displayName => switch (this) {
        PlayerPosition.south => 'You',
        PlayerPosition.west => 'West',
        PlayerPosition.north => 'Partner',
        PlayerPosition.east => 'East',
      };
}

enum Team {
  playerTeam,
  opponentTeam;

  Team get opponent =>
      this == Team.playerTeam ? Team.opponentTeam : Team.playerTeam;

  String get displayName => switch (this) {
        Team.playerTeam => 'Us',
        Team.opponentTeam => 'Them',
      };
}

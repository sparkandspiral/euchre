enum GamePhase {
  dealing,
  bidRound1,
  bidRound2,
  dealerDiscard,
  playing,
  trickComplete,
  roundComplete,
  gameOver;

  bool get isBidding => this == bidRound1 || this == bidRound2;
  bool get isActive => this == playing || this == dealerDiscard;
}

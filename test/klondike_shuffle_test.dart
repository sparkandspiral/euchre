import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/utils/shuffle.dart';

void main() {
  test('debugDeckIdsForSeed returns deterministic order', () {
    const expected = <int>[
      33,
      36,
      32,
      28,
      43,
      29,
      50,
      45,
      9,
      20,
      51,
      0,
      24,
      18,
      17,
      12,
      44,
      22,
      47,
      34,
      30,
      26,
      23,
      35,
      41,
      27,
      7,
      16,
      21,
      37,
      5,
      25,
      49,
      46,
      11,
      19,
      10,
      39,
      1,
      13,
      3,
      4,
      31,
      6,
      15,
      8,
      40,
      38,
      42,
      48,
      14,
      2,
    ];

    expect(debugDeckIdsForSeed(5, acesAtBottom: false), expected);
  });
}


import 'package:flutter/material.dart';
import 'package:euchre/styles/color_library.dart';

enum Background {
  green(fallbackColor: ColorLibrary.green600),
  blue(fallbackColor: ColorLibrary.red400),
  slate(fallbackColor: ColorLibrary.slate400),
  grey(fallbackColor: ColorLibrary.stone400);

  final Color fallbackColor;

  const Background({required this.fallbackColor});

  Widget build() => ColoredBox(color: fallbackColor);
}

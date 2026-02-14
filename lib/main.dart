import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:euchre/pages/home_page.dart';
import 'package:euchre/styles/playing_card_asset_bundle_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlayingCardAssetBundleCache.preloadAssets();

  runApp(ProviderScope(
    child: MaterialApp(
      title: 'Euchre',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.bold),
        ),
        canvasColor: Colors.transparent,
        chipTheme: ChipThemeData(
          color: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : Color(0xFF333333),
          ),
          showCheckmark: false,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
        ),
        sliderTheme: SliderThemeData(
          overlayShape: SliderComponentShape.noOverlay,
        ),
      ),
      home: HomePage(),
    ),
  ));
}

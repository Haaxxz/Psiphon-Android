import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/vpn_controller.dart';
import 'theme/psiphon_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: PsiphonPalette.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final controller = VpnController();
  await controller.init();

  runApp(PsiphonApp(controller: controller));
}

class PsiphonApp extends StatelessWidget {
  final VpnController controller;

  const PsiphonApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Psiphon',
      debugShowCheckedModeBanner: false,
      theme: buildPsiphonTheme(),
      home: HomeScreen(controller: controller),
    );
  }
}

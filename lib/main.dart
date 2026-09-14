import 'package:flutter/material.dart';

import 'app.dart';
import 'l10n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.load();
  runApp(const LgsPlusApp());
}

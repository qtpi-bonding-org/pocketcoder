import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrap();

  runApp(const App());
}

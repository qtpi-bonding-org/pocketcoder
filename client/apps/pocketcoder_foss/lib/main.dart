import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/app.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/boot/boot_routing_decider.dart';

import 'foss_app_module.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await bootstrap(appModule: FossAppModule());

  runApp(const App());
  await getIt<BootRoutingDecider>().start();
}

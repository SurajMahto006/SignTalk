import 'package:flutter/material.dart';

import 'app/sign_talk_app.dart';
import 'services/cloud/cloud_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudDatabase.instance.start();
  runApp(const SignTalkApp());
}

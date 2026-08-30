import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';
import 'data/session_store.dart';
import 'data/student_api.dart';
import 'pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config=AppConfig.fromEnvironment();
  if(!config.isConfigured){runApp(const ConfigErrorApp()); return;}
  await Supabase.initialize(url:config.supabaseUrl,publishableKey:config.supabasePublishableKey);
  runApp(MarefatApp(config:config,api:StudentApi(Supabase.instance.client),store:SessionStore()));
}

class ConfigErrorApp extends StatelessWidget { const ConfigErrorApp({super.key}); @override Widget build(BuildContext context)=>const MaterialApp(home:Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:Center(child:Padding(padding:EdgeInsets.all(24),child:Text('تنظیمات اتصال محیط آزمایشی کامل نیست.')))))) ;}

class MarefatApp extends StatelessWidget {
  const MarefatApp({super.key,required this.config,required this.api,required this.store});
  final AppConfig config; final StudentApi api; final SessionStore store;
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'آزمون معرفت',theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo),builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:child!),home:SessionGate(config:config,api:api,store:store));
}

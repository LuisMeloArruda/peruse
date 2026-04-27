import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://epfzdrnyvyoaqkxdrnbc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwZnpkcm55dnlvYXFreGRybmJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMDI5MzgsImV4cCI6MjA5Mjg3ODkzOH0.bdHdiM0unAtSxDMzUmTsGk962Th3y9ISEOC8djwEnYg',
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
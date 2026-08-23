import 'package:flutter/material.dart';
import 'package:peixi/features/library/library_page.dart';

class PeixiApp extends StatelessWidget {
  const PeixiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '陪析',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const LibraryPage(),
      );
}

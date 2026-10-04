import 'package:fixme_flutter/fixme_flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(FixmeFlutter.wrap(const ShopApp()));

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Shop',
        home: Scaffold(
          appBar: AppBar(title: const Text('Go Pro')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(
                width: 160,
                child: Text(r'$9.99 / month, billed yearly', key: ValueKey('price'), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 16),
              ElevatedButton(key: const ValueKey('buy'), onPressed: () {}, child: const Text('Subscribe')),
              TextButton(onPressed: () => FixmeFlutter.open(), child: const Text('Report a bug')),
            ]),
          ),
        ),
      );
}

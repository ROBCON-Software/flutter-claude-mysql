import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cards/odpocty_card.dart';

enum AppSection { odpocty, prehlad, statistiky, grafy, nastavenia }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppSection _section = AppSection.odpocty;

  String get _title {
    switch (_section) {
      case AppSection.odpocty:
        return 'Odpocty';
      case AppSection.prehlad:
        return 'Prehlad';
      case AppSection.statistiky:
        return 'Statistiky';
      case AppSection.grafy:
        return 'Grafy';
      case AppSection.nastavenia:
        return 'Nastavenia';
    }
  }

  Widget get _body {
    switch (_section) {
      case AppSection.odpocty:
        return const OdpoctyCard();
      default:
        return const SizedBox.shrink();
    }
  }

  void _select(AppSection section) {
    Navigator.pop(context);
    setState(() => _section = section);
  }

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukoncenie aplikacie'),
        content: const Text('Naozaj chces ukoncit appku?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('NIE')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ANO')),
        ],
      ),
    );
    if (confirmed == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('Meradla', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Odpocty'),
                selected: _section == AppSection.odpocty,
                onTap: () => _select(AppSection.odpocty),
              ),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.dashboard_outlined),
                title: Text('Prehlad'),
              ),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.bar_chart_outlined),
                title: Text('Statistiky'),
              ),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.show_chart),
                title: Text('Grafy'),
              ),
              const ListTile(
                enabled: false,
                leading: Icon(Icons.settings_outlined),
                title: Text('Nastavenia'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Exit'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmExit();
                },
              ),
            ],
          ),
        ),
      ),
      body: _body,
    );
  }
}

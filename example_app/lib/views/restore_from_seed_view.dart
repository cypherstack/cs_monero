import 'dart:async';
import 'dart:io';

import 'package:cs_monero/cs_monero.dart';
import 'package:flutter/material.dart';

import '../util.dart';
import '../widgets/coin_selector_widget.dart';

class RestoreFromSeedView extends StatefulWidget {
  const RestoreFromSeedView({super.key});

  @override
  State<RestoreFromSeedView> createState() => _RestoreFromSeedViewState();
}

class _RestoreFromSeedViewState extends State<RestoreFromSeedView> {
  final nameController = TextEditingController();
  final pwController = TextEditingController();
  final seedController = TextEditingController();
  final heightController = TextEditingController();

  String _type = "monero";
  bool _locked = false;

  Future<Wallet> restoreWallet(
    String type,
    String name,
    String password,
  ) async {
    final existing = await loadWalletNames(type);
    if (existing.contains(name)) {
      throw Exception("Wallet with name: \"$name\" already exists");
    }

    final path = await pathForWallet(
      name: name,
      type: type,
      createIfNotExists: true,
    );

    try {
      final Wallet wallet;
      switch (type) {
        case "monero":
          wallet = await MoneroWallet.restoreWalletFromSeed(
            path: path,
            password: password,
            seed: seedController.text,
            restoreHeight: int.tryParse(heightController.text) ?? 0,
            networkType: Network.mainnet,
          );
          break;

        default:
          throw Exception("Unknown wallet type: $type");
      }

      unawaited(wallet.rescanBlockchain());

      return wallet;
    } catch (e) {
      // delete dir on failure
      final dir = await pathForWalletDir(
        name: nameController.text,
        type: _type,
        createIfNotExists: true,
      );
      Directory(dir).deleteSync(recursive: true);
      rethrow;
    }
  }

  Future<void> _onPressed() async {
    if (_locked) return;
    setState(() {
      _locked = true;
    });

    try {
      final _ = await restoreWallet(
        _type,
        nameController.text,
        pwController.text,
      );

      if (mounted) {
        await showAdaptiveDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog.adaptive(
            title: const Text("Success!"),
            content: Text("${nameController.text} created."),
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e, s) {
      if (mounted) {
        await showAdaptiveDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog.adaptive(
            title: Text(e.toString()),
            content: Text(s.toString()),
          ),
        );
      }
    } finally {
      setState(() {
        _locked = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    pwController.dispose();
    heightController.dispose();
    seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore from seed'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CoinSelectorWidget(
          onChanged: (value) {
            setState(() {
              _type = value;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pwController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: seedController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Seed',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: heightController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Restore height (For 25 word seeds - OPTIONAL)',
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _locked ? null : _onPressed,
                  child: const Text("Restore"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

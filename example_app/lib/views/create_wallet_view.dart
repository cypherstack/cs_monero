import 'dart:io';

import 'package:cs_monero/cs_monero.dart';
import 'package:flutter/material.dart';

import '../util.dart';
import '../widgets/coin_selector_widget.dart';

class CreateWalletView extends StatefulWidget {
  const CreateWalletView({super.key});

  @override
  State<CreateWalletView> createState() => _CreateWalletViewState();
}

class _CreateWalletViewState extends State<CreateWalletView> {
  final nameController = TextEditingController();
  final pwController = TextEditingController();

  String _type = "monero";
  bool _locked = false;

  MoneroSeedType? _selectedXmrType;

  Future<Wallet> createWallet(String type, String name, String password) async {
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
          if (_selectedXmrType == null) {
            throw Exception("Select seed length!");
          }
          wallet = await MoneroWallet.create(
            path: path,
            password: password,
            seedType: _selectedXmrType!,
            networkType: Network.mainnet,
          );
          break;

        default:
          throw Exception("Unknown wallet type: $type");
      }

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
      final _ = await createWallet(
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a wallet'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CoinSelectorWidget(
          onChanged: (value) => setState(() => _type = value),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton(
                      hint: const Text("Select seed length"),
                      isExpanded: true,
                      value: _selectedXmrType,
                      items: [
                        ...MoneroSeedType.values.map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(e.name),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          if (value is MoneroSeedType) {
                            _selectedXmrType = value;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _locked ? null : _onPressed,
                  child: const Text("Create"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

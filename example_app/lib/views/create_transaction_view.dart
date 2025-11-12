import 'package:cs_monero/cs_monero.dart';
import 'package:flutter/material.dart';

import '../util.dart';
import '../widgets/info_item.dart';

class CreateTransactionView extends StatefulWidget {
  const CreateTransactionView({super.key, required this.wallet});

  final Wallet wallet;

  @override
  State<CreateTransactionView> createState() => _CreateTransactionViewState();
}

class _CreateTransactionViewState extends State<CreateTransactionView> {
  int lastId = 0;

  final List<(int, TextEditingController, TextEditingController)> recipients =
      [];

  void add() {
    setState(() {
      lastId++;
      recipients
          .add((lastId, TextEditingController(), TextEditingController()));
    });
  }

  void remove(int id) {
    final index = recipients.lastIndexWhere((e) => e.$1 == id);
    final removed = recipients.removeAt(index);
    removed.$2.dispose();
    removed.$3.dispose();
    setState(() {});
  }

  bool _lock = false;
  Future<void> preview() async {
    if (_lock) return;
    try {
      _lock = true;

      bool didError = false;

      final tx = await showLoading(
        whileFuture: recipients.length == 1
            ? widget.wallet.createTx(
                output: Recipient(
                  address: recipients.first.$2.text,
                  amount: (await widget.wallet
                      .amountFromString(recipients.first.$3.text))!,
                ),
                priority: TransactionPriority.normal,
                accountIndex: 0,
              )
            : widget.wallet.createTxMultiDest(
                outputs: (await Future.wait(
                  recipients.map(
                    (r) async => Recipient(
                      address: r.$2.text,
                      amount:
                          (await widget.wallet.amountFromString(r.$3.text))!,
                    ),
                  ),
                ))
                    .toList(growable: false),
                priority: TransactionPriority.normal,
                accountIndex: 0,
              ),
        context: context,
        onError: (e, s) async {
          didError = true;
          Logging.log?.e("Create tx failed", error: e, stackTrace: s);
          if (context.mounted) {
            await showAdaptiveDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (_) => AlertDialog.adaptive(
                title: Text(e.toString()),
                content: Text(s.toString()),
              ),
            );
          }
        },
      );

      if (didError) return;

      if (mounted) {
        await showConfirmDialog(context, widget.wallet, tx!);
      }
    } catch (e, s) {
      Logging.log?.e("Preview tx failed", error: e, stackTrace: s);
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
      _lock = false;
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => add());
  }

  @override
  void dispose() {
    for (final e in recipients) {
      e.$2.dispose();
      e.$3.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TextButton(
            onPressed: add,
            child: const Text("ADD RECIPIENT"),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                children: [
                  ...recipients.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RecipientForm(
                        key: Key("recipient_${r.$1}"),
                        id: r.$1,
                        addressController: r.$2,
                        amountController: r.$3,
                        close:
                            recipients.length == 1 ? null : () => remove(r.$1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: preview,
            child: const Text("Preview"),
          ),
        ],
      ),
    );
  }
}

class RecipientForm extends StatelessWidget {
  const RecipientForm({
    super.key,
    required this.id,
    required this.addressController,
    required this.amountController,
    required this.close,
  });

  final int id;
  final TextEditingController addressController;
  final TextEditingController amountController;
  final void Function()? close;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recipient"),
                close == null
                    ? Container()
                    : IconButton(
                        onPressed: close,
                        icon: const Icon(Icons.remove),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              autocorrect: false,
              controller: addressController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Address',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              autocorrect: false,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              controller: amountController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Amount',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showConfirmDialog(
  BuildContext context,
  Wallet wallet,
  PendingTransaction tx,
) async {
  bool _lock = false;
  Future<void> commit() async {
    if (_lock) return;
    try {
      _lock = true;

      bool didError = false;

      await showLoading(
        whileFuture: wallet.commitTx(tx),
        context: context,
        onError: (e, s) async {
          didError = true;
          Logging.log?.e("Commit tx failed", error: e, stackTrace: s);
          if (context.mounted) {
            await showAdaptiveDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (_) => AlertDialog.adaptive(
                title: Text(e.toString()),
                content: Text(s.toString()),
              ),
            );
          }
        },
      );

      if (didError) return;

      if (context.mounted) {
        await showAdaptiveDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (context) => AlertDialog.adaptive(
            title: const Text("Success!"),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text("OK"),
              ),
            ],
          ),
        );
        if (context.mounted) Navigator.of(context).pop();
      }
    } catch (e, s) {
      Logging.log?.e("Commit tx failed", error: e, stackTrace: s);
      if (context.mounted) {
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
      _lock = false;
    }
  }

  return await showAdaptiveDialog(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text("Transaction preview"),
      children: [
        InfoItem(
          label: "Amount",
          value: formattedAmount(
            tx.amount,
            wallet.runtimeType,
          ),
        ),
        InfoItem(
          label: "Fee",
          value: formattedAmount(
            tx.fee,
            wallet.runtimeType,
          ),
        ),
        InfoItem(label: "txid", value: tx.txid),
        InfoItem(label: "hex", value: tx.hex),
        const SizedBox(height: 16),
        TextButton(
          onPressed: commit,
          child: const Text("Commit tx"),
        ),
      ],
    ),
  );
}

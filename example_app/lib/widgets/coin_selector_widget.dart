import 'package:flutter/material.dart';

class CoinSelectorWidget extends StatefulWidget {
  const CoinSelectorWidget({
    super.key,
    this.onChanged,
    this.initialValue = "monero",
    this.child,
  }) : assert(initialValue == "monero");

  final void Function(String)? onChanged;
  final String initialValue;
  final Widget? child;

  @override
  State<CoinSelectorWidget> createState() => _CoinSelectorWidgetState();
}

class _CoinSelectorWidgetState extends State<CoinSelectorWidget> {
  late String _type;

  @override
  void initState() {
    _type = widget.initialValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(
              value: "monero",
              label: Text("Monero"),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _type = newSelection.first;
            });
            widget.onChanged?.call(_type);
          },
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

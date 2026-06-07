import 'package:flutter/material.dart';

class PmBrandingHeader extends StatelessWidget {
  final bool compact;
  final bool showBackButton;

  const PmBrandingHeader({
    Key? key,
    this.compact = true,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logoHeight = compact ? 28.0 : 44.0;
    final titleStyle = compact
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleMedium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 40),
          Image.asset(
            'assets/icon.png',
            height: logoHeight,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'blueprint collective',
              overflow: TextOverflow.ellipsis,
              style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

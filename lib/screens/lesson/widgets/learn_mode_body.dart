import 'package:flutter/material.dart';

class LearnModeBody extends StatelessWidget {
  final String sign;
  final VoidCallback onHearIt;

  const LearnModeBody({super.key, required this.sign, required this.onHearIt});

  String get _signName {
    const digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
    return digits.contains(sign) ? 'Number $sign' : 'Sign $sign';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sign,
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _signName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'ASL sign',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onHearIt,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                size: 18,
                color: Color(0xFF5BC8AC),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

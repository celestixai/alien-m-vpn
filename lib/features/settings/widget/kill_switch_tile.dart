import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/utils/platform_utils.dart';

/// alien-m: "Kill switch" entry. The real OS-level kill switch on Android is
/// the system "Always-on VPN" + "Block connections without VPN" pair, which an
/// app cannot toggle programmatically. So this guides the user there and
/// deep-links to the system VPN settings via the platform channel.
class KillSwitchTile extends StatelessWidget {
  const KillSwitchTile({super.key});

  static const _channel = MethodChannel("com.hiddify.app/platform");
  static const _accent = Color(0xFF6AD0FF);

  Future<void> _openVpnSettings() async {
    try {
      await _channel.invokeMethod<bool>("open_vpn_settings");
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isAndroid) return const SizedBox.shrink();
    return Material(
      child: ListTile(
        leading: const Icon(Icons.gpp_good_rounded, color: _accent),
        title: const Text("Kill switch"),
        subtitle: const Text("Блокировать интернет, когда VPN выключен"),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showSheet(context),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.gpp_good_rounded, color: _accent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Kill switch",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Чтобы интернет полностью блокировался, когда VPN не подключён "
                "(например, если туннель упал или приложение закрыто) — включите "
                "это один раз в системных настройках Android:",
              ),
              const SizedBox(height: 16),
              _step("1", "Нажмите «Открыть настройки VPN» ниже"),
              _step("2", "Нажмите ⚙ рядом с «alien-m VPN»"),
              _step("3", "Включите «Постоянная VPN» (Always-on VPN)"),
              _step("4", "Включите «Блокировать соединения без VPN»"),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text("Открыть настройки VPN"),
                  onPressed: () async {
                    await _openVpnSettings();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: _accent,
              child: Text(
                n,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF06060E),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(text))),
          ],
        ),
      );
}

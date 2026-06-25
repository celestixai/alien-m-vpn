import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// alien-m VPN — in-app registration gate.
/// User cannot enter the app until they register: email + invite code,
/// then a 6-digit code sent to their email. On success the subscription is
/// imported and the `registered` flag is set.
class RegistrationPage extends ConsumerStatefulWidget {
  const RegistrationPage({super.key});

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  static const _api = "https://vpn.alien-m.com";
  static const _bg = Color(0xFF06060E);
  static const _panel = Color(0xFF13131E);
  static const _border = Color(0xFF1C1C2D);
  static const _muted = Color(0xFF8A8AA0);
  static const _cyan = Color(0xFF6AD0FF);
  static const _purple = Color(0xFF9F7FFF);

  final _email = TextEditingController();
  final _invite = TextEditingController();
  final _vcode = TextEditingController();
  final _dio = Dio(BaseOptions(
    validateStatus: (_) => true,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  bool _loading = false;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _invite.dispose();
    _vcode.dispose();
    super.dispose();
  }

  Map _asMap(dynamic d) => d is Map ? d : <String, dynamic>{};

  Future<void> _register() async {
    final email = _email.text.trim();
    final code = _invite.text.trim();
    if (email.isEmpty || code.isEmpty) {
      setState(() => _error = "Введите email и инвайт-код");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _dio.post("$_api/api/register", data: {"email": email, "code": code});
      final m = _asMap(r.data);
      if (r.statusCode == 200 && m["status"] == "code_sent") {
        setState(() => _codeSent = true);
      } else if (r.statusCode == 200 && m["status"] == "ok") {
        await _activate(m["sub_url"]?.toString() ?? "");
      } else {
        setState(() => _error = m["message"]?.toString() ?? "Ошибка регистрации");
      }
    } catch (_) {
      setState(() => _error = "Нет связи с сервером");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final v = _vcode.text.trim();
    if (v.isEmpty) {
      setState(() => _error = "Введите код из письма");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _dio.post("$_api/api/verify", data: {"email": _email.text.trim(), "code": v});
      final m = _asMap(r.data);
      if (r.statusCode == 200 && m["status"] == "ok") {
        await _activate(m["sub_url"]?.toString() ?? "");
      } else {
        setState(() => _error = m["message"]?.toString() ?? "Неверный код");
      }
    } catch (_) {
      setState(() => _error = "Нет связи с сервером");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate(String subUrl) async {
    if (subUrl.isNotEmpty) {
      try {
        await ref.read(addProfileNotifierProvider.notifier).addClipboard(subUrl);
      } catch (_) {}
    }
    await ref.read(Preferences.registered.notifier).update(true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("🛸", style: TextStyle(fontSize: 56), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    "alien-m VPN",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _codeSent ? "Введите код из письма" : "Регистрация по приглашению",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 14),
                  ),
                  const SizedBox(height: 26),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0x333A1D1D),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0xFF5A2A2A)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFF3B3B3))),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!_codeSent) ...[
                    _field(_email, "Email", TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _field(_invite, "Инвайт-код", TextInputType.text),
                    const SizedBox(height: 20),
                    _button("Получить код", _register),
                  ] else ...[
                    _field(_vcode, "Код из письма", TextInputType.number),
                    const SizedBox(height: 20),
                    _button("Подтвердить и войти", _verify),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => setState(() {
                        _codeSent = false;
                        _error = null;
                      }),
                      child: const Text("← Назад", style: TextStyle(color: _cyan)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, TextInputType kt) => TextField(
        controller: c,
        keyboardType: kt,
        enabled: !_loading,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6B7686)),
          filled: true,
          fillColor: _panel,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _cyan)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _border)),
        ),
      );

  Widget _button(String label, VoidCallback onTap) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(colors: [_cyan, _purple]),
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06060E)))
              : Text(label, style: const TextStyle(color: Color(0xFF06060E), fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
}

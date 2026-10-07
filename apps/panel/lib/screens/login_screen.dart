import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../panel_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _institution = TextEditingController();
  String _title = 'Ebe';
  bool _register = false;
  bool _busy = false;
  String? _error;

  static const _titles = [
    'Ebe',
    'Uzm. Ebe',
    'Dr. Öğr. Üyesi',
    'Op. Dr.',
    'Doç. Dr.',
    'Prof. Dr.',
  ];

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _institution]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = context.read<PanelState>().repo;
    try {
      if (_register) {
        await repo.registerMidwife(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          title: _title,
          institution: _institution.text,
        );
      } else {
        await repo.signIn(_email.text, _password.text);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final repo = context.read<PanelState>().repo;
    final messenger = ScaffoldMessenger.of(context);
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Önce e-posta adresinizi yazın.');
      return;
    }
    try {
      await repo.sendPasswordReset(_email.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('Şifre sıfırlama bağlantısı gönderildi.')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = context.read<PanelState>().repo.isDemo;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 48,
                        color: PanelColors.peach,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nesta Ebe Paneli',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Gebelerinizin egzersiz güvenliğini izleyin',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PanelColors.inkSoft),
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Giriş')),
                          ButtonSegment(value: true, label: Text('Yeni hesap')),
                        ],
                        selected: {_register},
                        onSelectionChanged: (s) =>
                            setState(() => _register = s.first),
                      ),
                      const SizedBox(height: 16),
                      if (isDemo)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: PanelColors.skySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Demo modu: örnek verilerle çalışır. Herhangi bir '
                            'e-posta ve şifreyle giriş yapabilirsiniz.',
                          ),
                        ),
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad',
                          ),
                          validator: (v) => v == null || v.trim().length < 3
                              ? 'Adınızı girin.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _title,
                          decoration: const InputDecoration(labelText: 'Unvan'),
                          items: [
                            for (final t in _titles)
                              DropdownMenuItem(value: t, child: Text(t)),
                          ],
                          onChanged: (v) => setState(() => _title = v ?? 'Ebe'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _institution,
                          decoration: const InputDecoration(labelText: 'Kurum'),
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Kurumunuzu girin.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'E-posta'),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Geçerli bir e-posta girin.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Şifre'),
                        validator: (v) => v == null || v.length < 6
                            ? 'Şifre en az 6 karakter olmalıdır.'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: PanelColors.danger),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_register ? 'Hesap oluştur' : 'Giriş yap'),
                      ),
                      if (!_register)
                        TextButton(
                          onPressed: _reset,
                          child: const Text('Şifremi unuttum'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

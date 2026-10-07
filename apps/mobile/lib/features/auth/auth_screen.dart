import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/demo_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _register = true;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<AppState>().repo;
    if (_register) {
      await repo.register(_email.text, _password.text);
    } else {
      await repo.signIn(_email.text, _password.text);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce e-posta adresinizi yazın.')),
      );
      return;
    }
    await runWithFeedback(
      context,
      () => context.read<AppState>().repo.sendPasswordReset(_email.text),
      success: 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = context.read<AppState>().repo.isDemo;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              const NestaLogo(size: 64),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Kayıt Ol')),
                  ButtonSegment(value: false, label: Text('Giriş Yap')),
                ],
                selected: {_register},
                onSelectionChanged: (s) => setState(() => _register = s.first),
              ),
              const SizedBox(height: 20),
              if (isDemo) ...[
                const InfoBanner(
                  title: 'Demo modu',
                  text:
                      'Uygulama şu an demo modunda. Verileriniz yalnızca bu '
                      'telefonda saklanır. Herhangi bir e-posta ve en az 6 '
                      'karakterli bir şifreyle kayıt olabilirsiniz. Ebe davet '
                      'kodu: ${DemoRepository.demoInviteCode}',
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Geçerli bir e-posta adresi girin.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: [
                  _register
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v == null || v.length < 6
                    ? 'Şifre en az 6 karakter olmalıdır.'
                    : null,
              ),
              if (_register) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password2,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Şifre (tekrar)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v != _password.text ? 'Şifreler eşleşmiyor.' : null,
                ),
              ],
              const SizedBox(height: 24),
              BusyButton(
                label: _register ? 'KAYIT OL' : 'GİRİŞ YAP',
                onPressed: _submit,
              ),
              if (!_register)
                TextButton(
                  onPressed: _reset,
                  child: const Text('Şifremi unuttum'),
                ),
              const SizedBox(height: 16),
              const Text(
                'Bu uygulama gebeler içindir. Ebe ve hekimler ebe paneline web '
                'tarayıcısından giriş yapar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: NestaColors.inkSoft, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

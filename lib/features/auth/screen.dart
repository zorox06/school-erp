import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../../ui/schoolday_cover.dart';

part 'widgets/password_reset.dart';

Future<void> openPlatformAdmin(BuildContext context) async {
  final uri = Uri.https('schoolday-dun.vercel.app', '/', {'admin': '1'});
  try {
    if (await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) return;
  } catch (_) {
    // Browser availability varies by device.
  }
  if (context.mounted) {
    tell(context, 'Could not open the platform admin portal.');
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true, _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final controller = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await controller.auth.signIn(_email.text, _password.text);
    } on AuthException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              e.statusCode == '400' ||
                  e.message.toLowerCase().contains('credentials')
              ? 'That email and password don’t match. Please try again.'
              : 'We couldn’t sign you in. Check your connection and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'We couldn’t reach account services. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 490),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Brand(large: true),
                    ),
                    const SizedBox(height: 24),
                    const EntranceMotion(
                      child: SchooldayCover(
                        title: 'Welcome back.',
                        caption: 'Sign in with your school account.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FormLabel(
                      'Email address',
                      child: TextFormField(
                        key: const Key('login-email'),
                        controller: _email,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          hintText: 'Your school account email',
                          prefixIcon: Icon(LucideIcons.mail, size: 18),
                        ),
                        validator: (v) =>
                            v == null ||
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(v.trim())
                            ? 'Enter a valid email address'
                            : null,
                      ),
                    ),
                    FormLabel(
                      'Password',
                      child: TextFormField(
                        key: const Key('login-password'),
                        controller: _password,
                        obscureText: _hidden,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _busy ? null : _submit(),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(
                            LucideIcons.lockKeyhole,
                            size: 18,
                          ),
                          suffixIcon: IconButton(
                            tooltip: _hidden
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden ? LucideIcons.eye : LucideIcons.eyeOff,
                              size: 18,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter your password'
                            : null,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          sheetAnimationStyle: AnimationStyle(
                            duration: schoolMotion(context, 285, 140),
                            reverseDuration: schoolMotion(context, 190, 100),
                          ),
                          builder: (_) => PasswordResetSheet(
                            initialEmail: _email.text,
                            auth: AppScope.of(context).auth,
                          ),
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    if (_error != null) ...[
                      InfoBanner(
                        _error!,
                        color: context.tones.danger,
                        background: context.tones.coralWash,
                      ),
                      const SizedBox(height: 16),
                    ],
                    EntranceMotion(
                      follow: true,
                      child: PrimaryButton(
                        'Sign in',
                        icon: LucideIcons.arrowRight,
                        busy: _busy,
                        onPressed: _submit,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => openPlatformAdmin(context),
                      icon: const Icon(LucideIcons.externalLink, size: 15),
                      label: const Text('Platform admin'),
                    ),
                    const SizedBox(height: 18),
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

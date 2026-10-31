import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/data.dart';
import '../core/theme.dart';
import '../ui/components.dart';

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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Brand(), Tag('SCHOOL & HOME')],
                    ),
                    const SizedBox(height: 32),
                    const WelcomeArt(),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome back.',
                      style: textStyle(
                        27,
                        weight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A familiar place for every school day.\nSign in with the account your school shared.',
                      style: textStyle(13, color: Palette.muted, height: 1.65),
                    ),
                    const SizedBox(height: 25),
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
                        color: Palette.danger,
                        background: Palette.coralWash,
                      ),
                      const SizedBox(height: 16),
                    ],
                    PrimaryButton(
                      'Sign in',
                      icon: LucideIcons.arrowRight,
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.shieldCheck,
                          size: 14,
                          color: Palette.muted,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'One secure login. Your own school space.',
                            style: textStyle(10, color: Palette.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Divider(),
                    const SizedBox(height: 9),
                    TextButton(
                      key: const Key('open-preview'),
                      onPressed: () => showWorkspacePreview(context),
                      child: const Text('Preview the empty app'),
                    ),
                    Text(
                      'No accounts or school records are needed to explore.',
                      textAlign: TextAlign.center,
                      style: textStyle(10, color: Palette.muted),
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

class WelcomeArt extends StatelessWidget {
  const WelcomeArt({super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(27),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.teal, Palette.forest],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -37,
            top: -65,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .10),
                  width: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: -36,
            child: Transform.rotate(
              angle: -.5,
              child: Container(
                width: 97,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF9EC9AE).withValues(alpha: .16),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(90),
                    bottomRight: Radius.circular(90),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 25,
            top: 26,
            child: Icon(
              LucideIcons.sparkles,
              size: 22,
              color: const Color(0xFFDBEEC9).withValues(alpha: .7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GROWING TOGETHER',
                  style: textStyle(
                    9,
                    weight: FontWeight.w800,
                    color: const Color(0xFFBBDFD0),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'A little closer to\ntheir school day.',
                  style: textStyle(
                    28,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.27,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFEABF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Less to manage. More to share.',
                      style: textStyle(10, color: const Color(0xFFD6E9DF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showWorkspacePreview(BuildContext context) {
  final controller = AppScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          children: [
            Text(
              'Take a look around.',
              style: textStyle(24, weight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            Text(
              'Explore an empty workspace. Preview never signs you in, loads school records or grants account permissions.',
              style: textStyle(13, color: Palette.muted),
            ),
            const SizedBox(height: 22),
            for (final role in Workspace.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  key: Key('preview-${role.name}'),
                  onTap: () {
                    Navigator.pop(sheet);
                    controller.enterPreview(role);
                  },
                  child: SettingRow(
                    role.isStaff
                        ? LucideIcons.graduationCap
                        : LucideIcons.userRound,
                    '${role.label} workspace',
                    subtitle: 'Empty interface preview',
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class PasswordResetSheet extends StatefulWidget {
  final String initialEmail;
  final AuthRepository auth;
  const PasswordResetSheet({
    super.key,
    required this.initialEmail,
    required this.auth,
  });
  @override
  State<PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<PasswordResetSheet> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false, _sent = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.resetPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'We couldn’t send a reset link. Please try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 26,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _sent ? 'Check your inbox.' : 'Let’s get you back in.',
              style: textStyle(24, weight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              _sent
                  ? 'If an account exists for that email, a password reset link will arrive shortly.'
                  : 'Enter your account email and we’ll send a password reset link.',
              style: textStyle(13, color: Palette.muted),
            ),
            const SizedBox(height: 24),
            if (!_sent) ...[
              FormLabel(
                'Email address',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Your school account email',
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter your email address'
                      : null,
                ),
              ),
              if (_error != null) ...[
                InfoBanner(
                  _error!,
                  color: Palette.danger,
                  background: Palette.coralWash,
                ),
                const SizedBox(height: 14),
              ],
              PrimaryButton('Send reset link', onPressed: _send, busy: _busy),
            ] else
              PrimaryButton(
                'Back to sign in',
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    ),
  );
}

part of '../screen.dart';

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
              style: textStyle(13, color: context.tones.muted),
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
                  color: context.tones.danger,
                  background: context.tones.coralWash,
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

import 'package:flutter/material.dart';

import '../../services/auth/auth_service.dart';
import '../../theme/sign_talk_colors.dart';

enum AuthMode { signIn, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.signIn;

  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedPersonStatus = 'Prefer not to say';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const _personStatuses = [
    'Deaf',
    'Hard of hearing',
    'Deafblind',
    'Blind',
    'Low vision',
    'Non-speaking',
    'Speech difficulty',
    'Hearing',
    'Normal',
    'Prefer not to say',
  ];

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = AuthService.instance;
    final userId = _userIdController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == AuthMode.register) {
        if (password != _confirmPasswordController.text) {
          setState(() {
            _errorMessage = 'Passwords do not match.';
            _isLoading = false;
          });
          return;
        }

        final result = await auth.register(
          userId: userId,
          name: _nameController.text.trim(),
          password: password,
          email: _emailController.text.trim(),
          role: _selectedPersonStatus,
        );

        if (!mounted) return;
        if (!result.success) {
          setState(() => _errorMessage = result.message);
        }
      } else {
        final result = await auth.login(userId: userId, password: password);

        if (!mounted) return;
        if (!result.success) {
          setState(() => _errorMessage = result.message);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _useDemoAccount() async {
    _userIdController.text = AuthService.demoUserId;
    _passwordController.text = AuthService.demoPassword;
    setState(() {
      _errorMessage = null;
      _mode = AuthMode.signIn;
      _isLoading = true;
    });
    final result = await AuthService.instance.login(
      userId: AuthService.demoUserId,
      password: AuthService.demoPassword,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!result.success) _errorMessage = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    final phone = MediaQuery.sizeOf(context).width < 700;
    final heroHeight = phone ? (compact ? 88.0 : 118.0) : (compact ? 140.0 : 188.0);
    return Scaffold(
      backgroundColor: SignTalkColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: compact ? 4 : 12,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AuthHeroIllustration(height: heroHeight),
                    const SizedBox(height: 4),
                    _buildBrandHeader(),
                    SizedBox(height: compact ? 8 : 24),
                    Card(
                      elevation: 0,
                      color: SignTalkColors.card,
                      shadowColor: const Color(0x140F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(color: SignTalkColors.border),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          compact ? 12 : 18,
                          18,
                          compact ? 12 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildModeToggle(),
                            const SizedBox(height: 22),
                            if (_errorMessage != null) ...[
                              _buildErrorBanner(_errorMessage!),
                              const SizedBox(height: 16),
                            ],
                            if (_mode == AuthMode.register)
                              _buildRegisterFields()
                            else
                              _buildSignInFields(),
                            const SizedBox(height: 24),
                            _buildSubmitButton(),
                            if (_mode == AuthMode.signIn) ...[
                              const SizedBox(height: 10),
                              _buildDemoAccountButton(),
                            ],
                            const SizedBox(height: 14),
                            _buildFooterNote(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        const Text(
          'SignTalk',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: SignTalkColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sign in, or create an account',
          style: TextStyle(
            fontSize: 14,
            color: SignTalkColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.dividerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SignTalkColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                label: 'Sign In',
                selected: _mode == AuthMode.signIn,
                onTap: () {
                  setState(() {
                    _mode = AuthMode.signIn;
                    _errorMessage = null;
                  });
                },
              ),
            ),
            Expanded(
              child: _TabButton(
                label: 'Create account',
                selected: _mode == AuthMode.register,
                onTap: () {
                  setState(() {
                    _mode = AuthMode.register;
                    _errorMessage = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniqueIdNotice() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SignTalkColors.tintBlueBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 20,
              color: SignTalkColors.primaryBlue,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Choose a User ID. It is checked when you create the account, and it must be unique.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: SignTalkColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SignTalkColors.callRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SignTalkColors.callRed.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              size: 18,
              color: SignTalkColors.callRed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: SignTalkColors.callRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextFieldLabel('User ID'),
        TextFormField(
          controller: _userIdController,
          decoration: InputDecoration(
            hintText: 'Your User ID',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.alternate_email,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Please enter your User ID.'
              : null,
        ),
        const SizedBox(height: 16),
        _buildTextFieldLabel('Password'),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.lock_outline,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please enter your password.' : null,
        ),
      ],
    );
  }

  Widget _buildRegisterFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildUniqueIdNotice(),
        const SizedBox(height: 14),
        _buildTextFieldLabel('User ID (Required)'),
        TextFormField(
          controller: _userIdController,
          decoration: InputDecoration(
            hintText: 'Choose your User ID (e.g. suraj006)',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.alternate_email,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'User ID is required.';
            if (v.trim().length < 3) return 'Must be at least 3 characters.';
            if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(v.trim().toLowerCase())) {
              return 'Only letters, numbers, _ and . allowed.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildTextFieldLabel('Full Name'),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.person_outline,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 42),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Please enter your name.'
              : null,
        ),
        const SizedBox(height: 14),
        _buildTextFieldLabel('Email'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'name@example.com',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.mail_outline,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 42),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Enter an email you can open.';
            if (!email.contains('@') || !email.contains('.')) {
              return 'Enter a valid email address.';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildTextFieldLabel('Person status'),
        DropdownButtonFormField<String>(
          initialValue: _selectedPersonStatus,
          decoration: const InputDecoration(
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.accessibility_new_outlined,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 42),
          ),
          items: _personStatuses
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(r, style: const TextStyle(fontSize: 13.5)),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedPersonStatus = val);
          },
        ),
        const SizedBox(height: 14),
        _buildTextFieldLabel('Password (Min. 6 chars)'),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: 'Create a password',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.lock_outline,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            suffixIcon: IconButton(
              tooltip: _obscureConfirmPassword
                  ? 'Show password'
                  : 'Hide password',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required.';
            if (v.length < 6) return 'Password must be at least 6 characters.';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildTextFieldLabel('Confirm Password'),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            hintText: 'Re-enter your password',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.lock_clock_outlined,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: SignTalkColors.secondaryText,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please confirm your password.';
            if (v != _passwordController.text) return 'Passwords do not match.';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: SignTalkColors.primaryText,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _mode == AuthMode.register
                      ? Icons.person_add_alt_1
                      : Icons.login,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _mode == AuthMode.register
                        ? 'Create Account'
                        : 'Sign In to SignTalk',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDemoAccountButton() {
    return OutlinedButton.icon(
      onPressed: _useDemoAccount,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(
        Icons.flash_on,
        size: 18,
        color: SignTalkColors.primaryBlue,
      ),
      label: const Text(
        'Continue as guest',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 14,
            color: SignTalkColors.secondaryText,
          ),
          const SizedBox(width: 6),
          Text(
            _mode == AuthMode.register
                ? 'Your account is saved when you create it. Email confirmation codes need a mail service, which is not connected yet.'
                : 'Continue as guest opens the demo account. Log out any time to come back here.',
            style: TextStyle(
              fontSize: 11,
              color: SignTalkColors.secondaryText.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SignTalkColors.card : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 0.5 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? SignTalkColors.primaryBlue
                  : SignTalkColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHeroIllustration extends StatelessWidget {
  const _AuthHeroIllustration({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Illustration of two people communicating with sign language, speech, and text',
      image: true,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            'assets/images/signtalk-auth-hero.png',
            fit: BoxFit.cover,
            semanticLabel: 'SignTalk illustration showing two people communicating with sign language, speech, and text',
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(color: SignTalkColors.tintBlue),
              child: Center(
                child: Icon(
                  Icons.diversity_3_rounded,
                  size: 52,
                  color: SignTalkColors.primaryBlue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/auth/auth_service.dart';
import '../../theme/sign_talk_colors.dart';
import '../../widgets/google_logo.dart';

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
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedPersonStatus = 'Normal';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _otpRequested = false;
  String? _errorMessage;
  String? _userIdStatusMessage;
  bool? _isUserIdAvailable;

  static const _personStatuses = ['Mute', 'Deaf', 'Normal'];

  @override
  void initState() {
    super.initState();
    _userIdController.addListener(_onUserIdChanged);
  }

  @override
  void dispose() {
    _userIdController.removeListener(_onUserIdChanged);
    _userIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUserIdChanged() {
    if (_mode != AuthMode.register) return;
    final text = _userIdController.text.trim().toLowerCase();
    if (text.isEmpty) {
      setState(() {
        _isUserIdAvailable = null;
        _userIdStatusMessage = null;
      });
      return;
    }

    if (text.length < 3) {
      setState(() {
        _isUserIdAvailable = false;
        _userIdStatusMessage = 'User ID must be at least 3 characters.';
      });
      return;
    }

    final validIdRegex = RegExp(r'^[a-z0-9_.]+$');
    if (!validIdRegex.hasMatch(text)) {
      setState(() {
        _isUserIdAvailable = false;
        _userIdStatusMessage =
            'Use only letters, numbers, dot, and underscore.';
      });
      return;
    }

    final isAvail = AuthService.instance.isUserIdAvailable(text);
    setState(() {
      _isUserIdAvailable = isAvail;
      _userIdStatusMessage = isAvail
          ? '@$text is available!'
          : '@$text is already taken. Please choose another unique User ID.';
    });
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

  void _useDemoAccount() {
    _userIdController.text = 'demo_user';
    _passwordController.text = 'SignTalk@123';
    setState(() {
      _errorMessage = null;
      _mode = AuthMode.signIn;
    });
  }

  void _showAuthSetupMessage() {
    setState(() {
      _errorMessage =
          'Firebase is required to use Google login and phone OTP. '
          'Configure Firebase Authentication first.';
    });
  }

  void _requestOtp() {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter your phone number first.');
      return;
    }
    setState(() => _otpRequested = true);
    _showAuthSetupMessage();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
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
                    _AuthHeroIllustration(height: compact ? 40 : 235),
                    const SizedBox(height: 4),
                    _buildBrandHeader(),
                    SizedBox(height: compact ? 8 : 24),
                    Card(
                      elevation: 0,
                      color: SignTalkColors.card.withValues(alpha: 0.88),
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
                            const SizedBox(height: 14),
                            _buildDemoAccountButton(),
                            const SizedBox(height: 12),
                            _buildGoogleButton(),
                            const SizedBox(height: 18),
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
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: SignTalkColors.primaryBlue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SignTalkColors.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.back_hand_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'SignTalk',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: SignTalkColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bridging Indian Sign Language & Speech',
          style: TextStyle(
            fontSize: 14,
            color: SignTalkColors.secondaryText.withValues(alpha: 0.9),
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
                label: 'Register',
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
                'System Requirement: Each person must choose a User ID. Your User ID identifies you during video calling, translation, and messaging.',
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
            hintText: 'Enter your User ID (e.g. demo_user)',
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
            suffixIcon: _isUserIdAvailable == null
                ? null
                : Icon(
                    _isUserIdAvailable! ? Icons.check_circle : Icons.cancel,
                    color: _isUserIdAvailable!
                        ? SignTalkColors.successGreen
                        : SignTalkColors.callRed,
                    size: 20,
                  ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'User ID is required.';
            if (v.trim().length < 3) return 'Must be at least 3 characters.';
            if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(v.trim().toLowerCase())) {
              return 'Only letters, numbers, _ and . allowed.';
            }
            if (_isUserIdAvailable == false) {
              return 'This User ID is already taken. Choose another.';
            }
            return null;
          },
        ),
        if (_userIdStatusMessage != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _userIdStatusMessage!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _isUserIdAvailable == true
                    ? SignTalkColors.successGreen
                    : SignTalkColors.callRed,
              ),
            ),
          ),
        ],
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
        _buildTextFieldLabel('Email Address (Optional)'),
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
        ),
        const SizedBox(height: 14),
        _buildTextFieldLabel('Phone Number (OTP)'),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+91 98765 43210',
            prefixIcon: const Icon(Icons.phone_outlined),
            suffixIcon: TextButton(
              onPressed: _isLoading ? null : _requestOtp,
              child: const Text('Send OTP'),
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Phone number is required.'
              : null,
        ),
        if (_otpRequested) ...[
          const SizedBox(height: 14),
          _buildTextFieldLabel('OTP Verification'),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'Enter 6-digit OTP',
              prefixIcon: Icon(Icons.verified_user_outlined),
              counterText: '',
            ),
          ),
        ],
        const SizedBox(height: 14),
        _buildTextFieldLabel('Person Status'),
        DropdownButtonFormField<String>(
          value: _selectedPersonStatus,
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

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _showAuthSetupMessage,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF202124),
        side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const GoogleLogo(size: 20),
      label: Text(
        _mode == AuthMode.register
            ? 'Register with Google'
            : 'Continue with Google',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF202124),
        ),
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
        'Fill Demo Account (@demo_user)',
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
            'SignTalk Secure Session Authentication',
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

class _AuthHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / 680).clamp(0.1, size.height / 240);
    canvas.save();
    canvas.translate(
      (size.width - (680 * scale)) / 2,
      (size.height - (240 * scale)) / 2,
    );
    canvas.scale(scale, scale);
    final blue = Paint()..color = SignTalkColors.primaryBlue;
    final navy = Paint()..color = const Color(0xFF2C2532);
    final skin = Paint()..color = const Color(0xFFFFBD91);
    final lightSkin = Paint()..color = const Color(0xFFFFD0AB);
    final hair = Paint()..color = const Color(0xFF3A2430);
    final pale = Paint()..color = const Color(0xFFEAF4FF);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 8, 664, 222),
        const Radius.circular(32),
      ),
      Paint()..color = const Color(0xFFEAF5FF),
    );
    canvas.drawCircle(
      const Offset(102, 73),
      66,
      Paint()..color = const Color(0xFFD7EBFF),
    );
    canvas.drawCircle(
      const Offset(578, 99),
      76,
      Paint()..color = const Color(0xFFD7EBFF),
    );
    canvas.drawOval(
      const Rect.fromLTWH(286, 28, 112, 112),
      Paint()..color = const Color(0xFFCBE4FF),
    );

    _bubble(canvas, const Rect.fromLTWH(282, 34, 116, 62), pale.color);
    _drawHand(canvas, const Offset(315, 50), blue);
    _drawHand(canvas, const Offset(354, 50), blue);

    _bubble(canvas, const Rect.fromLTWH(408, 106, 104, 58), Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(423, 119, 28, 31),
        const Radius.circular(5),
      ),
      blue,
    );
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(431, 123));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(462, 123, 35, 6),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF9CB2D4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(462, 136, 27, 6),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF9CB2D4),
    );

    _bubble(canvas, const Rect.fromLTWH(516, 35, 62, 55), Colors.white);
    canvas.drawCircle(
      const Offset(547, 57),
      12,
      Paint()..color = SignTalkColors.tintBlue,
    );
    canvas.drawLine(
      const Offset(547, 51),
      const Offset(547, 66),
      blue
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      const Rect.fromLTWH(540, 51, 14, 21),
      0,
      3.14,
      false,
      blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.drawOval(const Rect.fromLTWH(83, 71, 88, 91), skin);
    canvas.drawOval(const Rect.fromLTWH(76, 62, 102, 55), hair);
    canvas.drawPath(
      Path()
        ..moveTo(62, 151)
        ..quadraticBezierTo(128, 119, 205, 157)
        ..lineTo(218, 230)
        ..lineTo(42, 230)
        ..close(),
      blue,
    );
    canvas.drawOval(const Rect.fromLTWH(103, 111, 9, 12), navy);
    canvas.drawOval(const Rect.fromLTWH(143, 111, 9, 12), navy);
    canvas.drawArc(
      const Rect.fromLTWH(108, 122, 39, 27),
      0,
      3.14,
      false,
      navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawLine(
      const Offset(137, 171),
      const Offset(204, 127),
      skin
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(205, 127),
      const Offset(215, 91),
      skin
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(216, 87), 7, skin);
    canvas.drawLine(
      const Offset(214, 91),
      const Offset(228, 74),
      skin
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawOval(const Rect.fromLTWH(494, 105, 79, 87), lightSkin);
    canvas.drawOval(const Rect.fromLTWH(482, 95, 106, 65), hair);
    canvas.drawPath(
      Path()
        ..moveTo(462, 171)
        ..quadraticBezierTo(531, 135, 604, 178)
        ..lineTo(628, 230)
        ..lineTo(442, 230)
        ..close(),
      Paint()..color = const Color(0xFFFFF3E9),
    );
    canvas.drawOval(const Rect.fromLTWH(514, 145, 9, 12), navy);
    canvas.drawOval(const Rect.fromLTWH(550, 145, 9, 12), navy);
    canvas.drawArc(
      const Rect.fromLTWH(516, 157, 37, 25),
      0,
      3.14,
      false,
      navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.restore();
  }

  void _bubble(Canvas canvas, Rect rect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()..color = color,
    );
  }

  void _drawHand(Canvas canvas, Offset origin, Paint paint) {
    canvas.drawCircle(origin + const Offset(0, 20), 12, paint);
    for (var index = 0; index < 4; index++) {
      final x = origin.dx + index * 9 - 13;
      canvas.drawLine(
        Offset(x, origin.dy + 18),
        Offset(x, origin.dy + (index == 1 ? -6 : 4)),
        paint
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

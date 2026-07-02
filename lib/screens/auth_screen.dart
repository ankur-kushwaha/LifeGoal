import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/goal_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _phoneVerificationId;
  bool _otpSent = false;

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    if (_isSignUp) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = authErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<GoalProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await _runAuth(() async {
      if (_isSignUp) {
        if (password != _confirmPasswordController.text) {
          throw Exception('Passwords do not match');
        }
        await provider.signUp(email, password);
      } else {
        await provider.signIn(email, password);
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    final provider = Provider.of<GoalProvider>(context, listen: false);
    await _runAuth(() => provider.signInWithGoogle());
  }

  Future<void> _sendPhoneCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      setState(() {
        _errorMessage = 'Enter phone with country code (e.g. +919876543210).';
      });
      return;
    }

    final provider = Provider.of<GoalProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await provider.sendPhoneVerificationCode(
      phone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _phoneVerificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
        });
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _verifyPhoneCode() async {
    final verificationId = _phoneVerificationId;
    if (verificationId == null) {
      setState(() {
        _errorMessage = 'Request a verification code first.';
      });
      return;
    }
    if (_otpController.text.trim().length < 4) {
      setState(() {
        _errorMessage = 'Enter the SMS verification code.';
      });
      return;
    }

    final provider = Provider.of<GoalProvider>(context, listen: false);
    await _runAuth(
      () => provider.signInWithPhoneCode(verificationId, _otpController.text.trim()),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmailForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isSignUp ? 'Create Account' : 'Welcome Back',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('Email Address', Icons.email_outlined),
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => _isSignUp ? null : _submitEmail(),
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.black38,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _fadeAnimation,
              child: TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitEmail(),
                style: const TextStyle(color: Colors.black87),
                decoration: _inputDecoration('Confirm Password', Icons.lock_outline),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildErrorBanner(),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: kMoneyGreen))
              : ElevatedButton(
                  style: _primaryButtonStyle(),
                  onPressed: _submitEmail,
                  child: Text(
                    _isSignUp ? 'Create Account' : 'Sign In',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : _toggleAuthMode,
            child: Text(
              _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
              style: const TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Phone Sign In',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Include country code (e.g. +91 for India)',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          style: const TextStyle(color: Colors.black87),
          decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _verifyPhoneCode(),
            style: const TextStyle(color: Colors.black87),
            decoration: _inputDecoration('SMS Code', Icons.sms_outlined),
          ),
        ],
        const SizedBox(height: 24),
        _buildErrorBanner(),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: kMoneyGreen))
        else if (!_otpSent)
          ElevatedButton(
            style: _primaryButtonStyle(),
            onPressed: _sendPhoneCode,
            child: const Text(
              'Send Verification Code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
        else ...[
          ElevatedButton(
            style: _primaryButtonStyle(),
            onPressed: _verifyPhoneCode,
            child: const Text(
              'Verify & Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _otpSent = false;
              _phoneVerificationId = null;
              _otpController.clear();
            }),
            child: const Text(
              'Change phone number',
              style: TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kMoneyGreen),
      filled: true,
      fillColor: kScaffoldBg.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: kMoneyGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: _isLoading ? null : _signInWithGoogle,
      icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
      label: const Text(
        'Continue with Google',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<GoalProvider>(context);
    final isFirebase = provider.isFirebaseMode;

    return Scaffold(
      backgroundColor: kScaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Hero(
                  tag: 'logo',
                  child: const AppLogo(size: 80),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LifeGoal AI',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFirebase
                    ? 'Sign in with email, Google, or phone to sync your goals'
                    : 'Running in Local Demo Mode (No Cloud Configured)',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 4,
                color: kCardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: kMoneyGreen,
                        unselectedLabelColor: Colors.black45,
                        indicatorColor: kMoneyGreen,
                        tabs: const [
                          Tab(text: 'Email'),
                          Tab(text: 'Phone'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          return _tabController.index == 0
                              ? _buildEmailForm(theme)
                              : _buildPhoneForm(theme);
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(color: Colors.black38)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildGoogleButton(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!isFirebase)
                Card(
                  color: Colors.amber[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Demo Mode Active',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Run scripts/setup_firebase.sh after firebase login to connect project 599945759594.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

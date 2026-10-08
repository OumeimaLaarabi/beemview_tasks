import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/message_banner.dart';
import '../../widgets/primary_button.dart';
import 'auth_cubit.dart';
import 'login_cubit.dart';
import 'login_validators.dart';

/// Email + password sign-in. The tenant subdomain is not a form field: it
/// comes from [AppConfig] and is added to the request by [AuthRepository].
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(context.read<AuthRepository>()),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  /// Field errors only appear after the first submit attempt, then update
  /// live as the user types.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Debug builds can pre-fill a test account from the config file.
    final config = context.read<AppConfig>();
    _email.text = config.devLoginEmail;
    _password.text = config.devLoginPassword;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_submitted) setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    TextInput.finishAutofillContext();
    context.read<LoginCubit>().submit(
      email: _email.text,
      password: _password.text,
      rememberMe: _rememberMe,
    );
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset your password'),
        content: const Text(
          'Password resets are handled by your workspace administrator. '
          'Contact them to set a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = context.read<AppConfig>().isConfigured;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the dark hero.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: BlocConsumer<LoginCubit, LoginState>(
          listenWhen: (previous, current) =>
              current.status == LoginStatus.success,
          listener: (context, state) =>
              context.read<AuthCubit>().loggedIn(state.user!),
          builder: (context, state) {
            final busy = state.isSubmitting;
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(minHeight: constraints.maxHeight * 0.41),
                    // The form sheet overlaps the hero by 24px.
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: _sheet(context, state, busy, configured),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sheet(
    BuildContext context,
    LoginState state,
    bool busy,
    bool configured,
  ) {
    final cubit = context.read<LoginCubit>();
    final error = state.status == LoginStatus.failure ? state.error : null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        26,
        30,
        26,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            autovalidateMode: _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Eyebrow('Welcome back', color: AppColors.brand),
                  const SizedBox(height: 7),
                  const Text(
                    'Sign in to your workspace',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 22,
                      letterSpacing: -0.6,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Enter your details to access your projects.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!configured) ...[
                    const MessageBanner(
                      tone: MessageTone.info,
                      title: 'App not configured',
                      message:
                          'This build has no workspace set. Run it with the '
                          'configuration file described in the README.',
                    ),
                    const SizedBox(height: 15),
                  ],
                  if (error != null) ...[
                    MessageBanner(title: "Couldn't sign in", message: error),
                    const SizedBox(height: 15),
                  ],
                  AppTextField(
                    label: 'Email address',
                    icon: LineIcons.mail,
                    controller: _email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    validator: LoginValidators.email,
                    onChanged: (_) => cubit.clearError(),
                  ),
                  const SizedBox(height: 15),
                  AppTextField(
                    label: 'Password',
                    icon: LineIcons.lock,
                    controller: _password,
                    enabled: !busy,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: LoginValidators.password,
                    onChanged: (_) => cubit.clearError(),
                    onSubmitted: (_) {
                      if (configured && !busy) _submit();
                    },
                    trailing: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: LineIcon(
                        _obscurePassword ? LineIcons.eye : LineIcons.eyeOff,
                        color: AppColors.fieldAction,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Options(
                    rememberMe: _rememberMe,
                    enabled: !busy,
                    onRememberMeChanged: (value) =>
                        setState(() => _rememberMe = value),
                    onForgotPassword: _showForgotPassword,
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Sign in',
                    loading: busy,
                    onPressed: configured ? _submit : null,
                  ),
                  const SizedBox(height: 17),
                  const _SecurityNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient header with the logo and the product pitch.
class _Hero extends StatelessWidget {
  const _Hero({required this.minHeight});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Decorative ring in the top-right corner.
            Positioned(
              right: -80,
              top: -55,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 34 + topInset, 28, 56),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (minHeight - 90 - topInset).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                // Logo pinned to the top, pitch to the bottom (CSS
                // space-between); the 62px spacer keeps them apart when the
                // text is tall enough to push past the minimum height.
                child: Stack(
                  alignment: AlignmentDirectional.bottomStart,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 30 + 32),
                          _Eyebrow(
                            'BeemView Tasks',
                            color: AppColors.brandOnDark,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Move work forward, together.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              height: 1.13,
                              letterSpacing: -1.2,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Stay focused, track progress, and deliver '
                            'great work with your team.',
                            style: TextStyle(
                              color: Color(0xBDFFFFFF),
                              fontSize: 14,
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PositionedDirectional(
                      top: 0,
                      start: 0,
                      child: BrandLogo(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small uppercase label above a heading.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// "Keep me signed in" and "Forgot password?".
class _Options extends StatelessWidget {
  const _Options({
    required this.rememberMe,
    required this.enabled,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
  });

  final bool rememberMe;
  final bool enabled;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    // Side by side normally; wraps onto two lines with very large text.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MergeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: enabled ? () => onRememberMeChanged(!rememberMe) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Material's checkbox is 18px; the design's is 15px.
                  SizedBox.square(
                    dimension: 15,
                    child: Transform.scale(
                      scale: 15 / 18,
                      child: Checkbox(
                        value: rememberMe,
                        onChanged: enabled
                            ? (value) => onRememberMeChanged(value ?? false)
                            : null,
                        activeColor: AppColors.brand,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Flexible(
                    child: Text(
                      'Keep me signed in',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LineIcon(LineIcons.lock, size: 15, color: AppColors.subtle),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Protected with enterprise-grade security',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtle, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

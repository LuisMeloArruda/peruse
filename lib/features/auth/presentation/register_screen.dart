import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/localization/locale_ext.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/widgets.dart';
import 'controller/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoadingDialogVisible = false;
  late final ProviderSubscription<AsyncValue<void>> _authSub;

  @override
  void initState() {
    super.initState();

    _authSub = ref.listenManual(authControllerProvider, (previous, next) async {
      if (next.isLoading && !_isLoadingDialogVisible) {
        _isLoadingDialogVisible = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        return;
      }

      if (!next.isLoading && _isLoadingDialogVisible) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        _isLoadingDialogVisible = false;
      }

      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
        return;
      }

      final finishedRegister = previous?.isLoading == true && !next.isLoading;
      if (finishedRegister) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final session = ref.read(authStateProvider).value;
        if (session == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('confirm_email_activate')),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub.close();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAction = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.translate('register_title'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final minContentHeight =
                constraints.maxHeight - (AppSpacing.lg * 2) - bottomInset;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minContentHeight < 0 ? 0 : minContentHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.translate('join_peruse'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.translate('register_subtitle'),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PeruseTextField(
                      controller: _emailController,
                      labelText: context.translate('email_address_label'),
                      hintText: context.translate('email_hint'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      prefixIcon: Icon(
                        Icons.mail_outlined,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.formFieldGap),
                    PeruseTextField(
                      controller: _passwordController,
                      labelText: context.translate('password_label'),
                      hintText: context.translate('password_hint'),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authAction.isLoading
                            ? null
                            : () {
                                ref
                                    .read(authControllerProvider.notifier)
                                    .register(
                                      _emailController.text.trim(),
                                      _passwordController.text.trim(),
                                    );
                              },
                        child: Text(context.translate('register')),
                      ),
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
}

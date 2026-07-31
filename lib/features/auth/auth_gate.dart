import 'dart:async';

import 'package:coro_lldm/core/supabase/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _authorizedUserKey = 'coro_lldm_authorized_user_id';

  StreamSubscription<AuthState>? _authSubscription;
  late Future<bool> _authorization;

  @override
  void initState() {
    super.initState();
    _authorization = _validateCurrentSession();
    _authSubscription =
        SupabaseService.client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      setState(() => _authorization = _validateCurrentSession());
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _validateCurrentSession() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return false;

    final cache = Hive.box('cache');
    try {
      final profile = await SupabaseService.client
          .from('perfiles')
          .select('estado')
          .eq('id', session.user.id)
          .maybeSingle();
      final active = profile?['estado'] == 'activo';
      if (active) {
        await cache.put(_authorizedUserKey, session.user.id);
        return true;
      }

      await cache.delete(_authorizedUserKey);
      await SupabaseService.client.auth.signOut();
      return false;
    } catch (_) {
      // Una sesión ya validada puede continuar usando su caché sin conexión.
      return cache.get(_authorizedUserKey) == session.user.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authorization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return widget.child;
        return const _LoginScreen();
      },
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No fue posible iniciar sesión.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.library_music_outlined, size: 52),
                      const SizedBox(height: 16),
                      Text(
                        'Coro LLDM',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        english
                            ? 'Sign in to access the private repertoire.'
                            : 'Inicia sesión para acceder al repertorio privado.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          labelText: english ? 'Email' : 'Correo',
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _loading ? null : _signIn(),
                        decoration: InputDecoration(
                          labelText: english ? 'Password' : 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _signIn,
                        child: _loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(english ? 'SIGN IN' : 'INICIAR SESIÓN'),
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

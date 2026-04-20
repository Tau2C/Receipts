import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipts/retailer_manager.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/retailers/biedronka.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BiedronkaLoginPage extends StatefulWidget {
  const BiedronkaLoginPage({super.key});

  @override
  State<BiedronkaLoginPage> createState() => _BiedronkaLoginPageState();
}

class _BiedronkaLoginPageState extends State<BiedronkaLoginPage> {
  bool _isLoading = false;
  final _biedronka = Biedronka(lastFetch: null);
  String? _pkceVerifierSecret;
  String? _csrfTokenSecret;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _exchangeCode(Uri uri) async {
    setState(() {
      _isLoading = true;
    });

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    if (code == null ||
        state == null ||
        _pkceVerifierSecret == null ||
        _csrfTokenSecret == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed: Invalid redirect')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      await _biedronka.exchangeCodeForToken(
        code: code,
        pkceVerifierSecret: _pkceVerifierSecret!,
        stateFromRedirect: state,
        csrfSecret: _csrfTokenSecret!,
      );

      final refreshToken = await _biedronka.getRefreshToken();
      if (refreshToken == null) {
        throw Exception("Did not get a refresh token");
      }

      final db = context.read<DatabaseService>();
      final success = await RetailerManager().loginRetailer(
        'biedronka',
        refreshToken,
        db,
      );

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login successful!')));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to store token after login.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred during token exchange: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authUrl = await _biedronka.getAuthenticationUrl();
      _pkceVerifierSecret = authUrl.pkceVerifierSecret;
      _csrfTokenSecret = authUrl.csrfTokenSecret;

      // Use a WebView to open the authentication URL
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Login to Biedronka')),
            body: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..setNavigationDelegate(
                  NavigationDelegate(
                    onNavigationRequest: (request) async {
                      if (request.url.startsWith(Biedronka.callbackUrl)) {
                        // Intercept the callback URL
                        final uri = Uri.parse(request.url);
                        await _exchangeCode(uri);
                        if (mounted) {
                          Navigator.of(context).pop(); // Close the webview
                        }
                        return NavigationDecision.prevent;
                      }
                      return NavigationDecision.navigate;
                    },
                  ),
                )
                ..loadRequest(Uri.parse(authUrl.url.toString())),
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to Biedronka')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _login,
                child: const Text('Login with Biedronka'),
              ),
      ),
    );
  }
}

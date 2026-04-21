import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipts/retailer_manager.dart';
import 'package:receipts/src/rust/api/database.dart';
import 'package:receipts/src/rust/api/retailers/lidl.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LidlLoginPage extends StatefulWidget {
  const LidlLoginPage({super.key});

  @override
  State<LidlLoginPage> createState() => _LidlLoginPageState();
}

class _LidlLoginPageState extends State<LidlLoginPage> {
  bool _isLoading = false;
  final _lidl = LidlClient();
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
      await _lidl.exchangeCodeForToken(
        code: code,
        pkceVerifierSecret: _pkceVerifierSecret!,
        stateFromRedirect: state,
        csrfSecret: _csrfTokenSecret!,
      );

      final refreshToken = _lidl.getRefreshToken();
      if (refreshToken == null) {
        throw Exception("Did not get a refresh token");
      }

      final db = context.read<DatabaseService>();
      final success = await RetailerManager().loginRetailer(
        'lidl',
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
      final authUrl = await _lidl.getAuthenticationUrl();
      _pkceVerifierSecret = authUrl.pkceVerifierSecret;
      _csrfTokenSecret = authUrl.csrfTokenSecret;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Login to Lidl')),
            body: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..setNavigationDelegate(
                  NavigationDelegate(
                    onNavigationRequest: (request) async {
                      if (request.url.startsWith(LidlClient.callbackUrl)) {
                        // Use LidlClient callbackUrl
                        // Intercept the callback URL
                        final uri = Uri.parse(request.url);
                        await _exchangeCode(uri);
                        if (mounted) {
                          Navigator.of(context).pop();
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
      appBar: AppBar(title: const Text('Login to Lidl')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _login,
                child: const Text('Login with Lidl'),
              ),
      ),
    );
  }
}

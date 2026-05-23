import 'package:flutter/foundation.dart'; // kIsWeb check karne ke liye
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Web redirect handle karne ke liye
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String url;

  const PaymentWebViewScreen({super.key, required this.url});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    if (kIsWeb) {
      // Agar Web hai to direct browser ko handle karne dein taake token expire ya redirect nah ho
      _redirectToSafepayWeb();
    } else {
      // Mobile ke liye purana tareeqa
      _initializeWebView();
    }
  }

  // Web par bina session drop kiye checkout page par bhejne ke liye
  Future<void> _redirectToSafepayWeb() async {
    final Uri checkoutUri = Uri.parse(widget.url);
    
    // LaunchMode.externalApplication browser ko force karta hai ke wo session generate kare
    if (await canLaunchUrl(checkoutUri)) {
      await launchUrl(
        checkoutUri, 
        mode: LaunchMode.externalApplication, // Naye tab me session maintain rakhta hai
      );
      
      if (mounted) {
        Navigator.pop(context, 'web_redirected');
      }
    } else {
      debugPrint("Safepay URL open nahi ho saki");
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('success')) {
              Navigator.pop(context, 'success');
              return NavigationDecision.prevent;
            }
            if (request.url.contains('cancel')) {
              Navigator.pop(context, 'cancel');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    // Web ke liye user ko screen par loading dikhegi jab tak tab khulta hai
    if (kIsWeb) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFB3300),
          ),
        ),
      );
    }

    // Mobile apps ke liye normal layout
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        backgroundColor: const Color(0xFFFB3300),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFB3300),
              ),
            ),
        ],
      ),
    );
  }
}
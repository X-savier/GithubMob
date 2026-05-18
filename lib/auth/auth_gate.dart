import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vxr_flutter/home_page.dart';
import 'package:vxr_flutter/login_screen.dart';
import 'package:vxr_flutter/theme/vxr_theme.dart';


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      //Listen to auth state changes
      stream: Supabase.instance.client.auth.onAuthStateChange,

      // Build appropriate page based on auth state
      builder: (context, snapshot) {
        //Loading..
        if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: DecoratedBox(
                decoration: BoxDecoration(gradient: VxrTokens.brandGradient),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            );
        }

        //check if there is a valid session currently
        final session = snapshot.hasData ? snapshot.data!.session! : null;

        if (session != null) {
          return HomeScreen();
        } else {
           return const LoginScreen();
        }
      },
    );
      
  }
}
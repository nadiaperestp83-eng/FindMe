import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quickstep_app/screens/movements/widgets/app_bar_2.dart';

import '../../../utils/colors.dart';
import 'components/create_account.dart';

/// Antes tinha 3 passos (criar conta -> verificar OTP -> criar perfil).
/// Com Supabase (confirmação de e-mail desativada + profile criado
/// automaticamente pelo trigger no banco), os passos 2 e 3 não existem
/// mais — CreateAccount sozinho fecha o cadastro.
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primary,
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: primary,
            elevation: 0.0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            flexibleSpace: Hero(
              tag: "appbar-hero-custom-1",
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const AnotherCustomAppBar(
                  title: "Sign Up",
                ),
              ),
            ),
            toolbarHeight: 100.h,
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: const CreateAccount(),
          ),
        ),
      ),
    );
  }
}

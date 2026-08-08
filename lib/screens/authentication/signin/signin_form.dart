import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quickstep_app/controllers/auth.dart';
import 'package:quickstep_app/screens/authentication/signin/signin_input_field.dart';
import 'package:quickstep_app/screens/authentication/signup/components/create_account.dart';
import 'package:quickstep_app/screens/components/top_snackbar.dart';
import 'package:quickstep_app/services/auth_service.dart';
import 'package:quickstep_app/utils/colors.dart';

import '../../../utils/helpers.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({
    Key? key,
  }) : super(key: key);

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  // Mesmo padrão de sempre: AuthState guarda o estado reativo global,
  // AuthService faz a chamada de verdade (agora pro Supabase).
  final auth = Get.put(AuthState());
  final _authService = AuthService();

  IsLoading _isLoading = IsLoading.idle;

  String? email;
  String? password;

  void _sign() async {
    if (email == null ||
        password == null ||
        email!.isEmpty ||
        password!.isEmpty) {
      return;
    }
    setState(() {
      _isLoading = IsLoading.loading;
    });
    try {
      await _authService.login(email!, password!);
      if (!mounted) return;
      // Não precisamos setar auth.isSignedIn manualmente: o listener em
      // auth_wrapper.dart escuta onAuthStateChange do Supabase e troca
      // WelcomeScreen -> LayoutPage sozinho assim que a sessão existir.
      showMessage(
        message: "Authenticated as $email",
        title: "Logged in successfully",
        type: MessageType.success,
      );
      setState(() {
        _isLoading = IsLoading.success;
      });
      popPage(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = IsLoading.idle;
      });
      showMessage(
        message: _translateAuthError(e.message),
        title: "Falha no login",
        type: MessageType.error,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = IsLoading.idle;
      });
      onUnkownError(e);
    }
  }

  String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final loading = _isLoading == IsLoading.loading;
    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SignInInputField(
            hintText: "Email",
            svg: "email.svg",
            onChanged: (value) {
              setState(() {
                email = value;
              });
            },
          ),
          SignInInputField(
            hintText: "Password",
            svg: "pwd.svg",
            isPwd: true,
            onChanged: (value) {
              setState(() {
                password = value;
              });
            },
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 10.h, bottom: 24.h),
            child: ElevatedButton.icon(
              onPressed: loading ? null : _sign,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: lightPrimary,
                disabledForegroundColor: white,
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 10.h),
              ),
              icon: loading
                  ? LoadingAnimationWidget.inkDrop(color: white, size: 18.sp)
                  : Icon(
                      CupertinoIcons.arrow_right,
                      color: const Color(0xFF9fcdf5),
                      size: 24.sp,
                    ),
              label: Text(
                loading ? " Loading..." : "Sign In",
                style: TextStyle(
                  fontSize: 14.sp,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

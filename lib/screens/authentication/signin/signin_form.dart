import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:quickstep_app/controllers/auth_controller.dart';
import 'package:quickstep_app/screens/authentication/signin/signin_input_field.dart';
import 'package:quickstep_app/screens/components/top_snackbar.dart';
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
  // Antes: final auth = Get.put(AuthState());  -> Node.js/Hive
  // Agora: mesmo padrão Get.put, apontando pro AuthController (Supabase).
  final auth = Get.put(AuthController(), permanent: true);

  String? email;
  String? password;

  void _sign() async {
    if (email == null ||
        password == null ||
        email!.isEmpty ||
        password!.isEmpty) {
      return;
    }

    final ok = await auth.signIn(email: email!, password: password!);

    if (!mounted) return;

    if (ok) {
      showMessage(
        message: "Authenticated as ${auth.currentUser.value?.email}",
        title: "Logged in successfully",
        type: MessageType.success,
      );
      // Fecha o dialog de login. A troca de tela acontece sozinha porque
      // auth.currentUser é reativo (Rxn<User>) e é atualizado
      // automaticamente pelo listener do Supabase no onInit do controller
      // — não precisa de "auth.isSignedIn.value = res" manual como antes.
      popPage(context);
    } else {
      showMessage(
        message: auth.errorMessage.value ?? "Não foi possível entrar.",
        title: "Falha no login",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = auth.isSubmitting.value;
      return Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SignInInputField(
              hintText: "Email",
              svg: "email.svg",
              onChanged: (value) {
                email = value;
              },
            ),
            SignInInputField(
              hintText: "Password",
              svg: "pwd.svg",
              isPwd: true,
              onChanged: (value) {
                password = value;
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 30.w, vertical: 10.h),
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
    });
  }
}

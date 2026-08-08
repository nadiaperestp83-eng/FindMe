import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quickstep_app/screens/components/top_snackbar.dart';

import '../../../../services/auth_service.dart';
import '../../../../utils/colors.dart';
import '../../../../utils/helpers.dart';
import '../widgets/text_input_field.dart';

enum IsLoading { loading, failed, success, idle }

class CreateAccount extends StatefulWidget {
  const CreateAccount({Key? key}) : super(key: key);

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final authService = AuthService();

  String? fullName;
  String? email;
  String? password;
  String? confirmPassword;
  IsLoading _isLoading = IsLoading.idle;

  void _onCreateAccount() async {
    setState(() {
      _isLoading = IsLoading.loading;
    });
    try {
      await authService.createAccount(fullName!, email!, password!);
      if (!mounted) return;
      setState(() {
        _isLoading = IsLoading.success;
      });
      showMessage(
        message: "Conta criada com sucesso. Bem-vindo(a), $fullName!",
        title: "Conta criada",
        type: MessageType.success,
      );
      // Cadastro em passo único: não existe mais tela de OTP nem de
      // criar perfil separada (o profile é criado automaticamente pelo
      // trigger no banco). Como a confirmação de e-mail está desativada
      // no Supabase, a sessão já fica ativa aqui — só precisamos fechar
      // as telas de autenticação empilhadas (signup + signin dialog) e
      // deixar o auth_wrapper.dart trocar para o app sozinho.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = IsLoading.idle;
      });
      showMessage(
        message: _translateAuthError(e.message),
        title: "Não foi possível criar a conta",
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
    if (lower.contains('user already registered')) {
      return 'Já existe uma conta com este e-mail.';
    }
    if (lower.contains('password should be at least')) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }
    if (lower.contains('unable to validate email')) {
      return 'E-mail inválido.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final loading = _isLoading == IsLoading.loading;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    addHorizontalSpace(5),
                    Icon(
                      Icons.add_circle_outline,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                Form(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 18.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Full name*".toUpperCase(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: primary.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        addVerticalSpace(8),
                        TextInputField(
                          hintText: "a name",
                          onChanged: (value) {
                            setState(() {
                              fullName = value;
                            });
                          },
                        ),
                        addVerticalSpace(18),
                        Text(
                          "Email*".toUpperCase(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: primary.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        addVerticalSpace(8),
                        TextInputField(
                          hintText: "an email",
                          onChanged: (value) {
                            setState(() {
                              email = value;
                            });
                          },
                        ),
                        addVerticalSpace(18),
                        Text(
                          "Password*".toUpperCase(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: primary.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        addVerticalSpace(8),
                        TextInputField(
                          hintText: "password",
                          obsecureText: true,
                          onChanged: (value) {
                            setState(() {
                              password = value;
                            });
                          },
                        ),
                        addVerticalSpace(18),
                        Text(
                          "Confirm password*".toUpperCase(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: primary.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        addVerticalSpace(8),
                        TextInputField(
                          hintText: "password again",
                          obsecureText: true,
                          onChanged: (value) {
                            setState(() {
                              confirmPassword = value;
                            });
                          },
                        ),
                        addVerticalSpace(30),
                        Center(
                          child: Directionality(
                            textDirection:
                                loading ? TextDirection.ltr : TextDirection.rtl,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (fullName == null ||
                                    email == null ||
                                    password == null ||
                                    confirmPassword == null) {
                                  showMessage(
                                    message:
                                        "All fields are required, please fill each text field below",
                                    title: "Validation Failed",
                                    type: MessageType.error,
                                  );
                                  return;
                                }
                                if (fullName!.isEmpty ||
                                    email!.isEmpty ||
                                    password!.isEmpty ||
                                    confirmPassword!.isEmpty) {
                                  showMessage(
                                    message:
                                        "All fields are required, please fill each text field below",
                                    title: "Validation Failed",
                                    type: MessageType.error,
                                  );
                                  return;
                                }
                                if (password != confirmPassword) {
                                  showMessage(
                                    message:
                                        "Password and confirm password must be equal",
                                    title: "Confirm Password",
                                    type: MessageType.error,
                                  );
                                  return;
                                }
                                _onCreateAccount();
                              },
                              style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: lightPrimary,
                                disabledForegroundColor: white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 30.w,
                                  vertical: 7.h,
                                ),
                              ),
                              icon: loading
                                  ? LoadingAnimationWidget.inkDrop(
                                      color: white, size: 18.sp)
                                  : Icon(
                                      CupertinoIcons.arrow_right,
                                      color: const Color(0xFF9fcdf5),
                                      size: 24.sp,
                                    ),
                              label: Text(
                                loading ? " LOADING..." : "CREATE ACCOUNT",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

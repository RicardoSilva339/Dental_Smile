import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dental_smile/api_service.dart';
import 'background.dart';

class PlansScreen extends StatefulWidget {
  final bool abrirCadastroDireto;
  final bool abrirLoginDireto;

  const PlansScreen({
    super.key,
    this.abrirCadastroDireto = false,
    this.abrirLoginDireto = false,
  });

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _croController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _lembrarEmail = false;
  bool _modoCadastro = false;

  @override
  void initState() {
    super.initState();
    _carregarEmailSalvo();

    if ((widget.abrirCadastroDireto || widget.abrirLoginDireto) && !_usuarioEstaLogado()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _modoCadastro = widget.abrirCadastroDireto;
        });
        _exibirDialogoAutenticacaoApenas();
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _croController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  bool _emailEhValido(String email) {
    final emailRegExp = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    return emailRegExp.hasMatch(email);
  }

  void _carregarEmailSalvo() {
    final boxUser = Hive.box('box_usuario');
    final emailAtivo = boxUser.get('email', defaultValue: '') as String;
    final lembrar = boxUser.get('lembrar_email', defaultValue: false) as bool;
    final emailSalvo = boxUser.get('email_salvo', defaultValue: '') as String;

    setState(() {
      _lembrarEmail = lembrar;
      if (emailAtivo.isEmpty) {
        if (lembrar && emailSalvo.isNotEmpty) {
          _emailController.text = emailSalvo;
        } else {
          _emailController.clear();
        }
      } else {
        _emailController.text = emailAtivo;
      }
    });
  }

  String _obterApiKeyAtual() {
    final boxUser = Hive.box('box_usuario');
    return boxUser.get('email', defaultValue: '') as String;
  }

  bool _usuarioEstaLogado() {
    return _obterApiKeyAtual().isNotEmpty;
  }

  Future<void> _fazerLogout() async {
    final boxUser = Hive.box('box_usuario');

    await boxUser.put('is_registrado', false);
    await boxUser.put('email', '');
    await boxUser.put('email_salvo', '');

    _emailController.clear();
    _senhaController.clear();
    _nomeController.clear();
    _croController.clear();

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text("Sessão encerrada com sucesso.")),
      );
    }
  }

  Future<void> _registrarHistoricoCompra(String nomePlano, int creditos, String preco) async {
    final boxCompras = Hive.box('box_compras');
    final emailAtual = _obterApiKeyAtual();
    final agora = DateTime.now();

    final novaCompra = {
      'emailDentista': emailAtual,
      'idCompra': 'REC-${agora.millisecondsSinceEpoch}',
      'plano': nomePlano,
      'creditos': creditos,
      'preco': preco,
      'dataIso': agora.toIso8601String(),
      'dataFormatada': "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} às ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}",
    };

    await boxCompras.add(novaCompra);
  }

  // 📧 MODAL DE VERIFICAÇÃO DO CÓDIGO OTP DE 6 DÍGITOS
  Future<bool> _exibirDialogoVerificacaoOtp(String email) async {
    final TextEditingController codigoController = TextEditingController();
    bool verificadoComSucesso = false;
    bool carregando = false;

    await showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: Color(0xFF5C6BC0)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Confirmar E-mail",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Enviamos um código de 6 dígitos para:\n$email\n\nDigite-o abaixo para ativar sua conta e liberar suas 3 simulações gratuitas:",
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codigoController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: InputDecoration(
                      hintText: "000000",
                      counterText: "",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: carregando ? null : () => Navigator.pop(ctx),
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: carregando
                    ? null
                    : () async {
                  final codigo = codigoController.text.trim();
                  if (codigo.length != 6) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text("Digite os 6 dígitos enviados ao seu e-mail.")),
                    );
                    return;
                  }

                  setModalState(() => carregando = true);
                  final res = await ApiService.verifyEmail(email: email, codigo: codigo);

                  if (res['success'] == true) {
                    final boxUser = Hive.box('box_usuario');
                    await boxUser.put('nome', res['nome'] ?? _nomeController.text.trim());
                    await boxUser.put('email', email);
                    await boxUser.put('is_registrado', true);

                    verificadoComSucesso = true;
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text("E-mail confirmado! Seus 3 créditos gratuitos foram liberados. 🎉"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (modalContext.mounted) {
                      setModalState(() => carregando = false);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(res['error'] ?? "Código incorreto."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: carregando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Validar Código", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    return verificadoComSucesso;
  }

  // 🔑 MODAL DE RECUPERAÇÃO DE SENHA
  Future<void> _exibirDialogoRecuperarSenha() async {
    final TextEditingController emailRecController = TextEditingController(text: _emailController.text.trim());
    final TextEditingController codigoRecController = TextEditingController();
    final TextEditingController novaSenhaController = TextEditingController();

    bool codigoEnviado = false;
    bool carregando = false;

    await showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset, color: Color(0xFF5C6BC0)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Recuperar Senha",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    codigoEnviado
                        ? "Digite o código de 6 dígitos enviado para o seu e-mail e defina sua nova senha."
                        : "Informe o e-mail cadastrado para receber o código de redefinição de senha.",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailRecController,
                    enabled: !codigoEnviado,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "E-mail Cadastrado",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  if (codigoEnviado) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: codigoRecController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: "Código de 6 Dígitos",
                        counterText: "",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: novaSenhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Nova Senha",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: carregando ? null : () => Navigator.pop(ctx),
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: carregando
                    ? null
                    : () async {
                  final email = emailRecController.text.trim();
                  if (!_emailEhValido(email)) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text("Informe um e-mail válido.")),
                    );
                    return;
                  }

                  if (!codigoEnviado) {
                    setModalState(() => carregando = true);
                    final res = await ApiService.forgotPassword(email: email);
                    if (modalContext.mounted) {
                      setModalState(() => carregando = false);
                    }

                    if (res['success'] == true) {
                      if (modalContext.mounted) {
                        setModalState(() => codigoEnviado = true);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text("Código enviado para o seu e-mail!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(res['error'] ?? "E-mail não encontrado."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    final codigo = codigoRecController.text.trim();
                    final novaSenha = novaSenhaController.text.trim();

                    if (codigo.length != 6 || novaSenha.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text("Preencha o código de 6 dígitos e a nova senha.")),
                      );
                      return;
                    }

                    setModalState(() => carregando = true);
                    final res = await ApiService.resetPassword(
                      email: email,
                      codigo: codigo,
                      novaSenha: novaSenha,
                    );

                    if (res['success'] == true) {
                      _emailController.text = email;
                      _senhaController.text = novaSenha;
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text("Senha redefinida com sucesso! Já pode entrar."),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (modalContext.mounted) {
                        setModalState(() => carregando = false);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(res['error'] ?? "Código inválido."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: carregando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(codigoEnviado ? "Salvar Nova Senha" : "Enviar Código", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 📱 MODAL DE LIMITE DE DISPOSITIVOS ATINGIDO
  Future<bool> _exibirDialogoLimiteDispositivos(String email, String mensagemServidor) async {
    bool desconectou = false;

    await showDialog(
      context: this.context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.devices_other, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Limite de Aparelhos",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          "$mensagemServidor\n\nDeseja desconectar os outros aparelhos vinculados a esta conta para liberar o acesso neste dispositivo agora?",
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final res = await ApiService.resetDevices(email: email);
              if (res['success'] == true) {
                desconectou = true;
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Desconectar Outros", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return desconectou;
  }

  Future<bool> _exibirDialogoAutenticacaoApenas() async {
    bool autenticadoComSucesso = false;
    bool carregando = false;

    await showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  _modoCadastro ? Icons.person_add_alt_1 : Icons.lock_outline,
                  color: const Color(0xFF5C6BC0),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _modoCadastro ? "Criar Nova Conta" : "Acesso do Dentista",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _modoCadastro
                        ? "Cadastre-se e confirme seu e-mail para liberar suas 3 simulações gratuitas."
                        : "Digite seu e-mail e senha para acessar sua conta.",
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  if (_modoCadastro) ...[
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: "Nome Completo / Clínica",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "E-mail do Dentista",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_modoCadastro) ...[
                    TextField(
                      controller: _croController,
                      decoration: InputDecoration(
                        labelText: "CRO / Registro Profissional (Opcional)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Sua Senha de Acesso",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),

                  if (!_modoCadastro)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _exibirDialogoRecuperarSenha();
                        },
                        child: const Text(
                          "Esqueci minha senha",
                          style: TextStyle(fontSize: 12, color: Color(0xFF5C6BC0), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                  Row(
                    children: [
                      Checkbox(
                        value: _lembrarEmail,
                        activeColor: const Color(0xFF5C6BC0),
                        onChanged: (val) {
                          setModalState(() {
                            _lembrarEmail = val ?? false;
                          });
                          setState(() {
                            _lembrarEmail = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "Permanecer e-mail na tela",
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),

                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _modoCadastro = !_modoCadastro;
                      });
                    },
                    child: Text(
                      _modoCadastro
                          ? "Já possui uma conta? Faça Login"
                          : "Ainda não tem conta? Cadastre-se aqui",
                      style: const TextStyle(color: Color(0xFF5C6BC0), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: carregando ? null : () => Navigator.pop(ctx),
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: carregando
                    ? null
                    : () async {
                  final email = _emailController.text.trim();
                  final senha = _senhaController.text.trim();

                  if (email.isEmpty || senha.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text("Por favor, preencha o E-mail e a Senha.")),
                    );
                    return;
                  }

                  if (!_emailEhValido(email)) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text("Por favor, insira um e-mail válido."),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final boxUser = Hive.box('box_usuario');
                  await boxUser.put('lembrar_email', _lembrarEmail);
                  if (_lembrarEmail) {
                    await boxUser.put('email_salvo', email);
                  } else {
                    await boxUser.put('email_salvo', '');
                  }

                  setModalState(() => carregando = true);

                  if (_modoCadastro) {
                    final res = await ApiService.register(
                      nome: _nomeController.text.trim(),
                      email: email,
                      cro: _croController.text.trim(),
                      senha: senha,
                    );

                    if (res['success'] == true) {
                      await boxUser.put('nome', _nomeController.text.trim());
                      await boxUser.put('cro', _croController.text.trim());

                      if (ctx.mounted) Navigator.pop(ctx);
                      final validou = await _exibirDialogoVerificacaoOtp(email);
                      if (validou) {
                        autenticadoComSucesso = true;
                      }
                    } else {
                      if (modalContext.mounted) {
                        setModalState(() => carregando = false);
                      }
                      if (mounted) {
                        String erroMsg = res['error'] ?? "Erro no cadastro.";
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(erroMsg), backgroundColor: Colors.red),
                        );
                      }
                    }
                  } else {
                    final res = await ApiService.login(email: email, senha: senha);

                    if (res['success'] == true) {
                      await boxUser.put('nome', res['nome'] ?? "Dentista");
                      await boxUser.put('email', email);
                      await boxUser.put('is_registrado', true);
                      autenticadoComSucesso = true;
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text("Login efetuado com sucesso!"), backgroundColor: Colors.green),
                        );
                      }
                    } else if (res['requer_verificacao'] == true) {
                      if (ctx.mounted) Navigator.pop(ctx);
                      final validou = await _exibirDialogoVerificacaoOtp(email);
                      if (validou) {
                        autenticadoComSucesso = true;
                      }
                    } else if (res['limite_dispositivos'] == true) {
                      if (modalContext.mounted) {
                        setModalState(() => carregando = false);
                      }
                      final msgErro = res['error'] ?? "Limite de dispositivos atingido.";
                      final desconectou = await _exibirDialogoLimiteDispositivos(email, msgErro);
                      if (desconectou) {
                        final retry = await ApiService.login(email: email, senha: senha);
                        if (retry['success'] == true) {
                          await boxUser.put('nome', retry['nome'] ?? "Dentista");
                          await boxUser.put('email', email);
                          await boxUser.put('is_registrado', true);
                          autenticadoComSucesso = true;
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text("Aparelho conectado com sucesso!"), backgroundColor: Colors.green),
                            );
                          }
                        }
                      }
                    } else {
                      if (modalContext.mounted) {
                        setModalState(() => carregando = false);
                      }
                      if (mounted) {
                        String erroMsg = res['error'] ?? "Erro ao efetuar login.";
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(erroMsg), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
                child: carregando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                  _modoCadastro ? "Cadastrar" : "Entrar",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    return autenticadoComSucesso;
  }

  // 💳 MODAL DE PIX DO MERCADO PAGO
  void _exibirModalPix({
    required String nomePlano,
    required String preco,
    required String qrCode,
    required int creditos,
  }) {
    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2, color: Color(0xFF5C6BC0), size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Pix - $nomePlano",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Valor: $preco",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 12),
              const Text(
                "Copie o código Pix abaixo ou utilize seu aplicativo de banco para pagar:",
                style: TextStyle(fontSize: 13, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  qrCode.isEmpty ? "Erro ao gerar código Pix." : qrCode,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: qrCode));
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text("Código Pix copiado para a área de transferência! 📋")),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text("Copiar Código Pix", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _registrarHistoricoCompra("$nomePlano (Pix)", creditos, preco);
              Navigator.pop(this.context, true);
            },
            child: const Text("Já Realizei o Pagamento", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5C6BC0))),
          ),
        ],
      ),
    );
  }

  // 💳 MODAL DE CARTÃO DE CRÉDITO (1x a 10x com repasse transparente)
  Future<void> _exibirModalCartaoCredito({
    required int creditos,
    required String nomePlano,
    required String precoBasePix,
  }) async {
    final TextEditingController numeroCartaoCtrl = TextEditingController();
    final TextEditingController nomeTitularCtrl = TextEditingController();
    final TextEditingController validadeCtrl = TextEditingController();
    final TextEditingController cvvCtrl = TextEditingController();
    final TextEditingController cpfCtrl = TextEditingController();

    List<dynamic> opcoesParcelas = [];
    int parcelasSelecionadas = 1;
    bool carregandoParcelas = true;
    bool processandoPagamento = false;

    final simRes = await ApiService.simularParcelasCartao(pacote: creditos.toString());
    if (simRes['success'] == true && simRes['opcoes_parcelamento'] is List) {
      opcoesParcelas = simRes['opcoes_parcelamento'];
    }
    carregandoParcelas = false;

    if (!mounted) return;

    await showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.credit_card, color: Color(0xFF5C6BC0), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Cartão - $nomePlano",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      "No Pix o valor é $precoBasePix (sem acréscimos). No cartão, selecione abaixo de 1x até 10x com os encargos da operadora já incluídos:",
                      style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (carregandoParcelas)
                    const Center(child: CircularProgressIndicator())
                  else if (opcoesParcelas.isNotEmpty) ...[
                    const Text(
                      "Parcelamento (1x a 10x):",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: parcelasSelecionadas,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: opcoesParcelas.map<DropdownMenuItem<int>>((op) {
                        final int numParcelas = op['parcelas'] ?? 1;
                        final String label = op['label'] ?? '${numParcelas}x';
                        return DropdownMenuItem<int>(
                          value: numParcelas,
                          child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: processandoPagamento
                          ? null
                          : (val) {
                        if (val != null) {
                          setModalState(() => parcelasSelecionadas = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: numeroCartaoCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 19,
                    decoration: InputDecoration(
                      labelText: "Número do Cartão",
                      hintText: "0000 0000 0000 0000",
                      counterText: "",
                      prefixIcon: const Icon(Icons.credit_card_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: nomeTitularCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: "Nome Impresso no Cartão",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: validadeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          inputFormatters: [_ValidadeCartaoFormatter()],
                          decoration: InputDecoration(
                            labelText: "Validade (MM/AA)",
                            hintText: "11/30",
                            counterText: "",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cvvCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "CVV",
                            hintText: "123",
                            counterText: "",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: cpfCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    inputFormatters: [_CpfFormatter()],
                    decoration: InputDecoration(
                      labelText: "CPF do Titular do Cartão",
                      hintText: "000.000.000-00",
                      counterText: "",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: processandoPagamento ? null : () => Navigator.pop(ctx),
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: processandoPagamento
                    ? null
                    : () async {
                  final numLimpo = numeroCartaoCtrl.text.replaceAll(RegExp(r'\D'), '');
                  final titular = nomeTitularCtrl.text.trim();
                  final digitsVal = validadeCtrl.text.replaceAll(RegExp(r'\D'), '');
                  final cvv = cvvCtrl.text.trim();
                  final cpf = cpfCtrl.text.replaceAll(RegExp(r'\D'), '');

                  if (numLimpo.length < 13 || titular.isEmpty || digitsVal.length != 4 || cvv.length < 3 || cpf.length != 11) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text("Preencha todos os dados do cartão e o CPF corretamente (MM/AA)."),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final int mes = int.tryParse(digitsVal.substring(0, 2)) ?? 0;
                  final int ano = int.tryParse(digitsVal.substring(2, 4)) ?? 0;

                  if (mes < 1 || mes > 12 || ano <= 0) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text("Validade inválida. Use o formato MM/AA.")),
                    );
                    return;
                  }

                  setModalState(() => processandoPagamento = true);

                  final tokenRes = await ApiService.gerarTokenCartaoMp(
                    cardNumber: numLimpo,
                    cardholderName: titular,
                    expirationMonth: mes,
                    expirationYear: ano,
                    securityCode: cvv,
                    cpfTitular: cpf,
                  );

                  if (tokenRes['success'] != true) {
                    if (modalContext.mounted) {
                      setModalState(() => processandoPagamento = false);
                    }
                    _mostrarErro(tokenRes['error'] ?? "Falha ao validar cartão.");
                    return;
                  }

                  final pagRes = await ApiService.criarPagamentoCartao(
                    apiKey: _obterApiKeyAtual(),
                    pacote: creditos.toString(),
                    cardToken: tokenRes['card_token'],
                    paymentMethodId: tokenRes['payment_method_id'] ?? 'visa',
                    installments: parcelasSelecionadas,
                    cpf: cpf,
                  );

                  if (modalContext.mounted) {
                    setModalState(() => processandoPagamento = false);
                  }

                  if (pagRes['success'] == true) {
                    final double totalPago = (pagRes['total_pago'] as num?)?.toDouble() ?? 0.0;
                    final String precoFinalLabel = totalPago > 0
                        ? "R\$ ${totalPago.toStringAsFixed(2).replaceAll('.', ',')} (${parcelasSelecionadas}x)"
                        : precoBasePix;

                    await _registrarHistoricoCompra("$nomePlano (Cartão)", creditos, precoFinalLabel);

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(pagRes['message'] ?? "Pagamento aprovado! Créditos adicionados."),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(this.context, true);
                    }
                  } else {
                    _mostrarErro(pagRes['error'] ?? "Pagamento recusado pela operadora.");
                  }
                },
                child: processandoPagamento
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Finalizar Pagamento", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🚀 MÉTODO DE COMPRA UNIFICADO (PIX OU CARTÃO DE CRÉDITO)
  Future<void> _comprarPlano(int creditos, String nomePlano, String preco, String detalhesDispositivos) async {
    if (!_usuarioEstaLogado()) {
      final autenticou = await _exibirDialogoAutenticacaoApenas();
      if (!autenticou) return;
    }

    if (!mounted) return;

    final metodoEscolhido = await showDialog<String>(
      context: this.context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shopping_cart_checkout, color: Color(0xFF5C6BC0), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Adquirir $nomePlano",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Valor no Pix: $preco",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5C6BC0)),
            ),
            const Text(
              "Sem taxas adicionais no Pix • Cartão em até 10x",
              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.devices, color: Color(0xFF5C6BC0), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detalhesDispositivos,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.indigo),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Escolha a forma de pagamento:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C6BC0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, 'pix'),
              icon: const Icon(Icons.pix, size: 20),
              label: Text("Pagar com Pix ($preco)", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo.shade800,
                side: BorderSide(color: Colors.indigo.shade400, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, 'cartao'),
              icon: const Icon(Icons.credit_card, size: 20),
              label: const Text("Cartão de Crédito (1x a 10x)", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (metodoEscolhido == null || !mounted) return;

    if (metodoEscolhido == 'cartao') {
      await _exibirModalCartaoCredito(
        creditos: creditos,
        nomePlano: nomePlano,
        precoBasePix: preco,
      );
      return;
    }

    final apiKeyAtual = _obterApiKeyAtual();

    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text("Gerando Pix para o $nomePlano ($preco)...")),
          ],
        ),
      ),
    );

    try {
      final respostaPix = await ApiService.criarPagamentoPix(
        apiKey: apiKeyAtual,
        pacote: creditos.toString(),
      );

      if (!mounted) return;
      Navigator.pop(this.context);

      if (respostaPix['success'] == true) {
        final String qrCodeCopiaECola = respostaPix['qr_code'] ?? '';
        final int creditosGerados = respostaPix['creditos'] ?? creditos;

        _exibirModalPix(
          nomePlano: nomePlano,
          preco: preco,
          qrCode: qrCodeCopiaECola,
          creditos: creditosGerados,
        );
      } else {
        _mostrarErro(respostaPix['error'] ?? "Não foi possível gerar o pagamento.");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(this.context);
      _mostrarErro("Erro ao conectar com o servidor de pagamentos: $e");
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  void _exibirHistoricoCompras() {
    final boxCompras = Hive.box('box_compras');
    final emailAtual = _obterApiKeyAtual();

    if (emailAtual.isEmpty) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text("Por favor, faça login para ver o seu histórico.")),
      );
      _exibirDialogoAutenticacaoApenas();
      return;
    }

    showModalBottomSheet(
      context: this.context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
            ),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: Color(0xFF5C6BC0)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Histórico de Recargas",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: boxCompras.listenable(),
                builder: (context, Box box, _) {
                  final comprasDoUsuario = box.values.where((item) {
                    if (item is Map) {
                      final mapItem = Map<String, dynamic>.from(item);
                      return mapItem['emailDentista'] == emailAtual;
                    }
                    return false;
                  }).toList();

                  if (comprasDoUsuario.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhuma recarga encontrada para esta conta.\nAs suas compras aparecerão aqui.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: comprasDoUsuario.length,
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(
                        comprasDoUsuario[comprasDoUsuario.length - 1 - index] as Map,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF5C6BC0).withValues(alpha: 0.15),
                            child: const Icon(Icons.add_shopping_cart, color: Color(0xFF5C6BC0)),
                          ),
                          title: Text(
                            "${item['plano']} (+${item['creditos']} créditos)",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            "Data: ${item['dataFormatada'] ?? "-"}",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Text(
                            "${item['preco']}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailAtual = _obterApiKeyAtual();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Loja de Créditos"),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        actions: [
          if (_usuarioEstaLogado())
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Sair / Trocar Conta",
              onPressed: _fazerLogout,
            ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: "Histórico de Compras",
            onPressed: _exibirHistoricoCompras,
          ),
        ],
      ),
      body: Background(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_usuarioEstaLogado())
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Sessão ativa: $emailAtual",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              const Text(
                "Escolha seu Pacote de Créditos",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Aumente sua capacidade de simulação e encante mais pacientes na clínica.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _exibirHistoricoCompras,
                icon: const Icon(Icons.history, size: 18),
                label: const Text("Ver Meu Histórico de Recargas", style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),

              // 1. PLANO INICIAL (10 Créditos - R$ 79,00)
              _buildPlanCard(
                titulo: "Plano Inicial",
                creditos: "10 Créditos",
                preco: "R\$ 79,00",
                detalhePreco: "R\$ 7,90 por simulação (Pix ou Cartão até 10x)",
                descricao: "Ideal para uso ocasional e testes em consultas diárias.",
                detalhesDispositivos: "Acesso liberado em 1 dispositivo (Uso individual).",
                corCard: Colors.white,
                isPopular: false,
                onPressed: () => _comprarPlano(10, "Plano Inicial", "R\$ 79,00", "Acesso liberado em 1 dispositivo (Uso individual)."),
              ),
              const SizedBox(height: 16),

              // 2. PLANO PROFISSIONAL (30 Créditos - R$ 199,00)
              _buildPlanCard(
                titulo: "Plano Profissional",
                creditos: "30 Créditos",
                preco: "R\$ 199,00",
                detalhePreco: "R\$ 6,63 por simulação (Economia de 16% • Pix ou até 10x)",
                descricao: "O plano preferido dos dentistas para uso recorrente na clínica.",
                detalhesDispositivos: "Benefício incluso: Acesso liberado para até 2 dispositivos simultâneos usando o mesmo e-mail!",
                corCard: Colors.indigo.shade50,
                isPopular: true,
                onPressed: () => _comprarPlano(30, "Plano Profissional", "R\$ 199,00", "Benefício incluso: Acesso liberado para até 2 dispositivos simultâneos usando o mesmo e-mail!"),
              ),
              const SizedBox(height: 16),

              // 3. PLANO MASTER (100 Créditos - R$ 579,00)
              _buildPlanCard(
                titulo: "Plano Master",
                creditos: "100 Créditos",
                preco: "R\$ 579,00",
                detalhePreco: "R\$ 5,79 por simulação (Melhor custo-benefício • Pix ou até 10x)",
                descricao: "Para clínicas de alto fluxo com múltiplos profissionais.",
                detalhesDispositivos: "Benefício incluso: Acesso liberado para até 3 dispositivos simultâneos usando o mesmo e-mail!",
                corCard: Colors.white,
                isPopular: false,
                onPressed: () => _comprarPlano(100, "Plano Master", "R\$ 579,00", "Benefício incluso: Acesso liberado para até 3 dispositivos simultâneos usando o mesmo e-mail!"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String titulo,
    required String creditos,
    required String preco,
    required String detalhePreco,
    required String descricao,
    required String detalhesDispositivos,
    required Color corCard,
    required bool isPopular,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: corCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
                if (isPopular)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "MAIS VENDIDO 🌟",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              creditos,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              preco,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
            ),
            Text(
              detalhePreco,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              descricao,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.devices_other, size: 16, color: Color(0xFF5C6BC0)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      detalhesDispositivos,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPopular ? const Color(0xFF5C6BC0) : Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onPressed,
                child: const Text("Comprar Pacote", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidadeCartaoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitado = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < limitado.length; i++) {
      buffer.write(limitado[i]);
      if (i == 1 && limitado.length > 2) {
        buffer.write('/');
      }
    }

    final textoFormatado = buffer.toString();
    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitado = digitsOnly.length > 11 ? digitsOnly.substring(0, 11) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < limitado.length; i++) {
      buffer.write(limitado[i]);
      if ((i == 2 || i == 5) && i != limitado.length - 1) {
        buffer.write('.');
      } else if (i == 8 && i != limitado.length - 1) {
        buffer.write('-');
      }
    }

    final textoFormatado = buffer.toString();
    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}
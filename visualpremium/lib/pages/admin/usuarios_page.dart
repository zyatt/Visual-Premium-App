import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:visualpremium/providers/auth_provider.dart';
import 'package:visualpremium/theme.dart';
import '../../../data/usuarios_repository.dart';
import '../../models/usuario_item.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final _repository = UsuariosApiRepository();
  List<UsuarioItem> _usuarios = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final usuarios = await _repository.fetchUsuarios();
      setState(() {
        _usuarios = usuarios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showUsuarioDialog({UsuarioItem? usuario}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _UsuarioDialog(usuario: usuario),
    );

    if (result == true) {
      _loadUsuarios();
    }
  }

  Future<void> _deleteUsuario(UsuarioItem usuario) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmar exclusão',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Deseja realmente excluir o usuário "${usuario.nome}"?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.18),
                          ),
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        child: const Text('Excluir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  
    if (confirm != true) return;

    try {
      await _repository.deleteUsuario(usuario.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário excluído'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadUsuarios();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().contains('própria conta')
            ? 'Não permitido'
            : 'Erro ao excluir usuário: $e';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Row(
                  children: [
                    ExcludeFocus(
                      child: IconButton(
                        onPressed: () => context.go('/admin'),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Voltar',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.people,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Gerenciar Usuários',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExcludeFocus(
                      child: ElevatedButton.icon(
                        onPressed: () => _showUsuarioDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Novo Usuário'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ExcludeFocus(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Erro ao carregar usuários',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _loadUsuarios,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            )
                          : _usuarios.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 64,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Nenhum usuário cadastrado',
                                        style: theme.textTheme.titleLarge,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  itemCount: _usuarios.length,
                                  itemBuilder: (context, index) {
                                    final usuario = _usuarios[index];
                                    return _UsuarioCard(
                                      usuario: usuario,
                                      onEdit: () => _showUsuarioDialog(usuario: usuario),
                                      onDelete: () => _deleteUsuario(usuario),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 32,
            right: 32,
            child: ExcludeFocus(
              child: IconButton(
                onPressed: _isLoading ? null : _loadUsuarios,
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar',
              ),
            ),
          ),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  final UsuarioItem usuario;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UsuarioCard({
    required this.usuario,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isCurrentUser = authProvider.currentUser?.id == usuario.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onEdit,
        splashColor: Colors.transparent,
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        focusColor: Colors.transparent,
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: usuario.isAdmin
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
          child: Text(
            usuario.nome.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: usuario.isAdmin
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              usuario.nome,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            
            if (usuario.role == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ADMIN',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            
            if (usuario.role == 'compras')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'COMPRAS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ),
            
            if (usuario.role == 'user')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ORÇAMENTISTA',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            
            const SizedBox(width: 8),
            
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'VOCÊ',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            usuario.username,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        trailing: ExcludeFocus(
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: isCurrentUser 
                ? 'Não permitido' 
                : 'Excluir usuário',
            color: isCurrentUser 
                ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.7),
            style: IconButton.styleFrom(
              hoverColor: Colors.red.withValues(alpha: 0.1),
            ),
            onPressed: isCurrentUser ? null : onDelete,
          ),
        ),
      ),
    );
  }
}

class _UsuarioDialog extends StatefulWidget {
  final UsuarioItem? usuario;

  const _UsuarioDialog({this.usuario});

  @override
  State<_UsuarioDialog> createState() => _UsuarioDialogState();
}

class _UsuarioDialogState extends State<_UsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nomeController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'user';
  bool _ativo = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.usuario != null) {
      _usernameController.text = widget.usuario!.username;
      _nomeController.text = widget.usuario!.nome;
      _role = widget.usuario!.role;
      _ativo = widget.usuario!.ativo;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nomeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = UsuariosApiRepository();
      final data = {
        'username': _usernameController.text.trim(),
        'nome': _nomeController.text.trim(),
        'role': _role,
        'ativo': _ativo,
      };

      if (_passwordController.text.isNotEmpty) {
        data['password'] = _passwordController.text;
      }

      if (widget.usuario == null) {
        if (_passwordController.text.isEmpty) {
          throw Exception('Senha é obrigatória para novos usuários');
        }
        await repository.createUsuario(data);
      } else {
        await repository.updateUsuario(widget.usuario!.id, data);

        // Se editou o próprio usuário logado, atualiza o AuthProvider
        if (mounted) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser?.id == widget.usuario!.id) {
      await authProvider.updateCurrentUser(
        username: _usernameController.text.trim(),
        nome: _nomeController.text.trim(),
      );
    }
  }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.usuario == null
                  ? 'Usuário criado'
                  : 'Usuário atualizado',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.usuario != null;

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeFocus(
                child: Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.person_add,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Editar Usuário' : 'Novo Usuário',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: isEditing ? 'Nova senha (opcional)' : 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: ExcludeFocus(
                    child: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                validator: (value) {
                  if (!isEditing && (value == null || value.isEmpty)) {
                    return 'Senha é obrigatória';
                  }
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Senha deve ter no mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Função',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Orçamentista')),
                  DropdownMenuItem(value: 'compras', child: Text('Compras')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              ExcludeFocus(
                child: SwitchListTile(
                  title: const Text('Usuário ativo'),
                  subtitle: Text(
                    _ativo
                        ? 'Usuário pode fazer login'
                        : 'Usuário não pode fazer login',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: _ativo,
                  onChanged: (value) {
                    setState(() => _ativo = value);
                  },
                ),
              ),
              const SizedBox(height: 24),
              ExcludeFocus(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: _isLoading ? null : _handleSave,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Salvar' : 'Criar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
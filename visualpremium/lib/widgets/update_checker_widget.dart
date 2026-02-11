import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';
import '../widgets/auto_update_dialog.dart';
import '../providers/auth_provider.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({
    super.key,
    required this.child,
  });

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) return;

    final updateInfo = await UpdateService.checkForUpdates();

    if (updateInfo != null && mounted) {
      await AutoUpdateDialog.show(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
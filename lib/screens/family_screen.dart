import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/family_model.dart';
import '../providers/goal_provider.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _inviteEmailController = TextEditingController();
  final _familyNameController = TextEditingController();
  bool _isInviting = false;
  bool _isSavingName = false;
  bool _familyNameInitialized = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _inviteMember(GoalProvider provider) async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isInviting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await provider.inviteFamilyMember(email);
      _inviteEmailController.clear();
      setState(() => _successMessage = 'Invitation sent to $email');
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
    } finally {
      setState(() => _isInviting = false);
    }
  }

  Future<void> _saveFamilyName(GoalProvider provider) async {
    final name = _familyNameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSavingName = true;
      _errorMessage = null;
    });

    try {
      await provider.updateFamilyName(name);
      setState(() => _successMessage = 'Family name updated');
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
    } finally {
      setState(() => _isSavingName = false);
    }
  }

  Future<void> _confirmRemoveMember(GoalProvider provider, FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Remove Member', style: TextStyle(color: Colors.black87)),
        content: Text(
          'Remove ${member.label} from your family? They will lose access to shared goals.',
          style: const TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await provider.removeFamilyMember(member.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.label} removed from family')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context);
    final family = provider.family;
    final members = provider.familyMembers;
    final pendingInvites = provider.pendingInvites;
    final isAdmin = provider.isFamilyAdmin;

    if (!_familyNameInitialized && family != null) {
      _familyNameController.text = family.name;
      _familyNameInitialized = true;
    }

    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        title: const Text('Family', style: TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_errorMessage != null)
            _buildBanner(_errorMessage!, Colors.redAccent),
          if (_successMessage != null)
            _buildBanner(_successMessage!, kMoneyGreen),
          _buildFamilyHeader(family, isAdmin, provider),
          const SizedBox(height: 24),
          _buildSectionTitle('Members (${members.length})'),
          const SizedBox(height: 8),
          ...members.map((member) => _buildMemberTile(member, isAdmin, provider)),
          if (pendingInvites.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Pending Invitations (${pendingInvites.length})'),
            const SizedBox(height: 8),
            ...pendingInvites.map(_buildInviteTile),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Invite by Email'),
            const SizedBox(height: 8),
            _buildInviteForm(provider),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: const Text(
              'All family members can view and manage shared goals. Only the admin can invite or remove members.',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(String message, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(message, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: kMoneyGreen,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildFamilyHeader(FamilyInfo? family, bool isAdmin, GoalProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kMoneyGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.family_restroom, color: kMoneyGreen, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family?.name ?? 'My Family',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${provider.familyMembers.length} member${provider.familyMembers.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isAdmin) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _familyNameController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Family Name',
                labelStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: kScaffoldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                suffixIcon: _isSavingName
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kMoneyGreen),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.check, color: kMoneyGreen),
                        onPressed: () => _saveFamilyName(provider),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberTile(FamilyMember member, bool isAdmin, GoalProvider provider) {
    final isCurrentUser = member.userId == provider.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kMoneyGreen.withOpacity(0.15),
          child: Text(
            member.label[0].toUpperCase(),
            style: const TextStyle(color: kMoneyGreen, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          member.label,
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          member.email,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kMoneyGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(color: kMoneyGreen, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            if (isAdmin && !member.isAdmin && !isCurrentUser)
              IconButton(
                icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 20),
                onPressed: () => _confirmRemoveMember(provider, member),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteTile(FamilyInvite invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: const Icon(Icons.mail_outline, color: Colors.orange),
        title: Text(invite.email, style: const TextStyle(color: Colors.black87)),
        subtitle: const Text('Waiting to accept', style: TextStyle(color: Colors.black45, fontSize: 12)),
      ),
    );
  }

  Widget _buildInviteForm(GoalProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _inviteEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Email address',
              hintText: 'partner@example.com',
              labelStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: kScaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMoneyGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isInviting ? null : () => _inviteMember(provider),
            icon: _isInviting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(
              _isInviting ? 'Sending...' : 'Send Invitation',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

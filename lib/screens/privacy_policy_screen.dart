import 'package:flutter/material.dart';
import '../constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String effectiveDate = 'July 2, 2026';
  static const String contactEmail = 'support@lifegoal.app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroCard(),
          const SizedBox(height: 16),
          _section(
            '1. Who we are',
            'LifeGoal AI ("LifeGoal", "we", "us") is a financial goal planning application '
            'that helps you track savings goals, calculate SIP requirements, and share plans with your family. '
            'This policy explains how we collect, use, and protect your information when you use our mobile app and website.',
          ),
          _section(
            '2. Information we collect',
            'Account information: When you sign up, we collect your email address and authentication credentials '
            'through Firebase Authentication. If you use Google Sign-In, we receive your name and email from Google.\n\n'
            'Financial goal data: Goals you create (names, target amounts, dates, savings progress, inflation and return assumptions) '
            'are stored in Google Cloud Firestore.\n\n'
            'Family data: If you use family sharing, we store family membership, member email addresses, and pending invitations.\n\n'
            'Settings: Global preferences such as inflation rate, expected return, and reference dates are stored with your family profile.\n\n'
            'Device and usage data: Firebase and our hosting provider may collect standard technical logs '
            '(IP address, browser type, device type, crash logs) to operate and secure the service.',
          ),
          _section(
            '3. How we use your information',
            'We use your information to:\n'
            '• Authenticate you and sync your data across devices\n'
            '• Store and display your financial goals and family-shared plans\n'
            '• Send and process family invitations by email\n'
            '• Maintain, secure, and improve the app\n'
            '• Respond to support requests',
          ),
          _section(
            '4. How we share your information',
            'Family members: Goals and settings in your family group are visible to all members of that family.\n\n'
            'Service providers: We use Google Firebase (Authentication, Firestore, Hosting) to run the app. '
            'Google processes data according to its own privacy policy.\n\n'
            'We do not sell your personal information. We do not share your data with advertisers.',
          ),
          _section(
            '5. Data storage and security',
            'Your data is stored in Google Cloud Firestore (database region: asia-south1). '
            'Access is protected by Firebase Authentication and Firestore security rules so only you and your family members '
            'can read or modify shared data. Passwords are handled by Firebase and are not stored in plain text by LifeGoal.',
          ),
          _section(
            '6. Data retention',
            'We retain your account and goal data for as long as your account is active. '
            'If you delete individual goals, they are removed from our database. '
            'Family invitations that have been accepted or expired may remain in logs for a limited period.',
          ),
          _section(
            '7. Your choices and rights',
            'You can update or delete goals at any time within the app. '
            'Family admins can remove members from a family group. '
            'To request account deletion or a copy of your data, contact us at $contactEmail. '
            'You may stop using the app and sign out at any time.',
          ),
          _section(
            '8. Children\'s privacy',
            'LifeGoal AI is not directed at children under 13. We do not knowingly collect personal information from children. '
            'If you believe a child has provided us data, please contact us and we will delete it.',
          ),
          _section(
            '9. International users',
            'If you access LifeGoal from outside India, your information may be processed in countries where our service providers operate, '
            'including the United States (Google Cloud). By using the app, you consent to this transfer.',
          ),
          _section(
            '10. Changes to this policy',
            'We may update this Privacy Policy from time to time. We will revise the "Effective date" at the top when we do. '
            'Continued use of the app after changes means you accept the updated policy.',
          ),
          _section(
            '11. Contact us',
            'For privacy questions or data requests, email us at:\n\n$contactEmail',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: kMoneyGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'LifeGoal AI Privacy Policy',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Effective date: $effectiveDate',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: kMoneyGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

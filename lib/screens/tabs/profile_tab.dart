import 'package:flutter/material.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      children: [
        // بطاقة الحساب
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12.withOpacity(.04), blurRadius: 8, offset: const Offset(0,3))],
          ),
          child: Row(
            children: [
              const CircleAvatar(radius: 28, backgroundColor: Color(0xFFEDEDED), child: Icon(Icons.person, size: 28, color: Colors.black54)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('اسم المستخدم', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('user@example.com', style: TextStyle(color: Colors.black54)),
                ]),
              ),
              TextButton(onPressed: () {/* TODO */}, child: const Text('تعديل')),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // إعدادات عامة
        _SectionHeader('الإعدادات العامة'),
        _SettingTile(icon: Icons.color_lens, title: 'المظهر', subtitle: 'فاتح / داكن', onTap: () {}),
        _SettingTile(icon: Icons.notifications, title: 'الإشعارات', subtitle: 'تشغيل الإشعارات', onTap: () {}),
        _SettingTile(icon: Icons.lock, title: 'الخصوصية والأمان', subtitle: 'كلمات المرور والدخول', onTap: () {}),

        const SizedBox(height: 16),

        _SectionHeader('أخرى'),
        _SettingTile(icon: Icons.help_outline, title: 'المساعدة', subtitle: 'الأسئلة الشائعة والتواصل', onTap: () {}),
        _SettingTile(icon: Icons.info_outline, title: 'عن التطبيق', subtitle: 'الإصدار والترخيص', onTap: () {}),

        const SizedBox(height: 24),

        // تسجيل خروج
        ElevatedButton.icon(
          onPressed: () {/* TODO: sign out */},
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(59, 59, 59, 1),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingTile({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFEDEDED),
          child: Icon(icon, color: Colors.black54),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: Colors.black.withOpacity(.6))) : null,
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}

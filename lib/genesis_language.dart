import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agc_luxury_theme.dart';

/// 10 supported language choices. Core actions are translated; extended content uses
/// English fallback until professionally reviewed translations are available.
class GenesisLanguage {
  static final selected = ValueNotifier<String>('pl');
  static const storageKey = 'genesis_language_v1';
  static const translations = {
  'en': {
    'name': 'English',
    'login': 'Log in',
    'signup': 'Create account',
    'language': 'Language',
    'account': 'Account',
    'ranking': 'Ranking',
    'simulator': 'Simulator',
    'invite': 'Invite friends',
    'email': 'Email',
    'password': 'Password',
    'share': 'Share',
    'logout': 'Log out',
    'copy': 'Copy my link',
    'confirm': 'Confirm referral code',
    'welcome': 'Welcome to THE GENESIS ERA'
  },
  'zh': {
    'name': '中文',
    'login': '登录',
    'signup': '创建账户',
    'language': '语言',
    'account': '账户',
    'ranking': '排行榜',
    'simulator': '模拟器',
    'invite': '邀请朋友',
    'email': '电子邮件',
    'password': '密码',
    'share': '分享',
    'logout': '退出登录',
    'copy': '复制邀请链接',
    'confirm': '确认推荐码',
    'welcome': '欢迎加入 THE GENESIS ERA'
  },
  'hi': {
    'name': 'हिन्दी',
    'login': 'लॉग इन',
    'signup': 'खाता बनाएं',
    'language': 'भाषा',
    'account': 'खाता',
    'ranking': 'रैंकिंग',
    'simulator': 'सिम्युलेटर',
    'invite': 'दोस्तों को आमंत्रित करें',
    'email': 'ईमेल',
    'password': 'पासवर्ड',
    'share': 'शेयर करें',
    'logout': 'लॉग आउट',
    'copy': 'लिंक कॉपी करें',
    'confirm': 'कोड की पुष्टि करें',
    'welcome': 'THE GENESIS ERA में स्वागत है'
  },
  'es': {
    'name': 'Español',
    'login': 'Iniciar sesión',
    'signup': 'Crear cuenta',
    'language': 'Idioma',
    'account': 'Cuenta',
    'ranking': 'Clasificación',
    'simulator': 'Simulador',
    'invite': 'Invitar amigos',
    'email': 'Correo electrónico',
    'password': 'Contraseña',
    'share': 'Compartir',
    'logout': 'Cerrar sesión',
    'copy': 'Copiar mi enlace',
    'confirm': 'Confirmar código',
    'welcome': 'Bienvenido a THE GENESIS ERA'
  },
  'ar': {
    'name': 'العربية',
    'login': 'تسجيل الدخول',
    'signup': 'إنشاء حساب',
    'language': 'اللغة',
    'account': 'الحساب',
    'ranking': 'الترتيب',
    'simulator': 'المحاكي',
    'invite': 'دعوة الأصدقاء',
    'email': 'البريد الإلكتروني',
    'password': 'كلمة المرور',
    'share': 'مشاركة',
    'logout': 'تسجيل الخروج',
    'copy': 'نسخ الرابط',
    'confirm': 'تأكيد الرمز',
    'welcome': 'مرحباً بك في THE GENESIS ERA'
  },
  'fr': {
    'name': 'Français',
    'login': 'Se connecter',
    'signup': 'Créer un compte',
    'language': 'Langue',
    'account': 'Compte',
    'ranking': 'Classement',
    'simulator': 'Simulateur',
    'invite': 'Inviter des amis',
    'email': 'E-mail',
    'password': 'Mot de passe',
    'share': 'Partager',
    'logout': 'Déconnexion',
    'copy': 'Copier mon lien',
    'confirm': 'Confirmer le code',
    'welcome': 'Bienvenue dans THE GENESIS ERA'
  },
  'pt': {
    'name': 'Português',
    'login': 'Entrar',
    'signup': 'Criar conta',
    'language': 'Idioma',
    'account': 'Conta',
    'ranking': 'Classificação',
    'simulator': 'Simulador',
    'invite': 'Convidar amigos',
    'email': 'E-mail',
    'password': 'Senha',
    'share': 'Compartilhar',
    'logout': 'Sair',
    'copy': 'Copiar meu link',
    'confirm': 'Confirmar código',
    'welcome': 'Bem-vindo ao THE GENESIS ERA'
  },
  'ru': {
    'name': 'Русский',
    'login': 'Войти',
    'signup': 'Создать аккаунт',
    'language': 'Язык',
    'account': 'Аккаунт',
    'ranking': 'Рейтинг',
    'simulator': 'Симулятор',
    'invite': 'Пригласить друзей',
    'email': 'Эл. почта',
    'password': 'Пароль',
    'share': 'Поделиться',
    'logout': 'Выйти',
    'copy': 'Скопировать ссылку',
    'confirm': 'Подтвердить код',
    'welcome': 'Добро пожаловать в THE GENESIS ERA'
  },
  'de': {
    'name': 'Deutsch',
    'login': 'Anmelden',
    'signup': 'Konto erstellen',
    'language': 'Sprache',
    'account': 'Konto',
    'ranking': 'Rangliste',
    'simulator': 'Simulator',
    'invite': 'Freunde einladen',
    'email': 'E-Mail',
    'password': 'Passwort',
    'share': 'Teilen',
    'logout': 'Abmelden',
    'copy': 'Link kopieren',
    'confirm': 'Code bestätigen',
    'welcome': 'Willkommen bei THE GENESIS ERA'
  },
  'pl': {
    'name': 'Polski',
    'login': 'Zaloguj się',
    'signup': 'Utwórz konto',
    'language': 'Język',
    'account': 'Konto',
    'ranking': 'Ranking',
    'simulator': 'Symulator',
    'invite': 'Zaproś znajomych',
    'email': 'E-mail',
    'password': 'Hasło',
    'share': 'Udostępnij',
    'logout': 'Wyloguj',
    'copy': 'Kopiuj mój link',
    'confirm': 'Zatwierdź kod polecenia',
    'welcome': 'Witaj w THE GENESIS ERA'
  }
};
  /// Polish source and English fallback for long-form copy until each locale is reviewed.
  static String copy(String polish, String english) =>
      selected.value == 'pl' ? polish : english;

  static String t(String key) =>
      translations[selected.value]?[key] ??
      translations['en']?[key] ?? key;
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved != null && translations.containsKey(saved)) selected.value = saved;
    } catch (_) { /* local storage may be unavailable in private browsing */ }
  }
  static Future<void> setLanguage(String code) async {
    if (!translations.containsKey(code)) return;
    selected.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, code);
    } catch (_) { /* choice still applies to current session */ }
  }
}

class GenesisLanguagePicker extends StatelessWidget {
  const GenesisLanguagePicker({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: GenesisLanguage.selected,
    builder: (context, code, _) => PopupMenuButton<String>(
      tooltip: GenesisLanguage.t('language'),
      onSelected: GenesisLanguage.setLanguage,
      constraints: const BoxConstraints(maxHeight: 440, minWidth: 240),
      initialValue: code,
      itemBuilder: (context) => [
        for (final entry in GenesisLanguage.translations.entries)
          PopupMenuItem<String>(
            value: entry.key,
            child: Row(children: [
              if (entry.key == code) const Icon(Icons.check, color: AgcLuxury.champagne, size: 18)
              else const SizedBox(width: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('${entry.value['name']} (${entry.key.toUpperCase()})')),
            ]),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language, color: AgcLuxury.champagne, size: 20),
          const SizedBox(width: 6),
          Text(code.toUpperCase(), style: const TextStyle(
            color: AgcLuxury.champagne, fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_drop_down, color: AgcLuxury.champagne),
        ]),
      ),
    ),
  );
}

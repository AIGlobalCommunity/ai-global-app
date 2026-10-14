import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agc_luxury_theme.dart';

/// 50 language choices. Core actions are translated; extended content uses
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
  'bn': {
    'name': 'বাংলা',
    'login': 'লগ ইন',
    'signup': 'অ্যাকাউন্ট তৈরি করুন',
    'language': 'ভাষা',
    'account': 'অ্যাকাউন্ট'
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
  'ur': {
    'name': 'اردو',
    'login': 'لاگ ان',
    'signup': 'اکاؤنٹ بنائیں',
    'language': 'زبان',
    'account': 'اکاؤنٹ'
  },
  'id': {
    'name': 'Bahasa Indonesia',
    'login': 'Masuk',
    'signup': 'Buat akun',
    'language': 'Bahasa',
    'account': 'Akun',
    'ranking': 'Peringkat',
    'simulator': 'Simulator',
    'invite': 'Undang teman',
    'email': 'Email',
    'password': 'Kata sandi',
    'share': 'Bagikan',
    'logout': 'Keluar',
    'copy': 'Salin tautan',
    'confirm': 'Konfirmasi kode',
    'welcome': 'Selamat datang di THE GENESIS ERA'
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
  'ja': {
    'name': '日本語',
    'login': 'ログイン',
    'signup': 'アカウント作成',
    'language': '言語',
    'account': 'アカウント',
    'ranking': 'ランキング',
    'simulator': 'シミュレーター',
    'invite': '友達を招待',
    'email': 'メール',
    'password': 'パスワード',
    'share': '共有',
    'logout': 'ログアウト',
    'copy': 'リンクをコピー',
    'confirm': 'コードを確認',
    'welcome': 'THE GENESIS ERA へようこそ'
  },
  'sw': {
    'name': 'Kiswahili',
    'login': 'Ingia',
    'signup': 'Fungua akaunti',
    'language': 'Lugha',
    'account': 'Akaunti'
  },
  'mr': {
    'name': 'मराठी',
    'login': 'लॉग इन',
    'signup': 'खाते तयार करा',
    'language': 'भाषा',
    'account': 'खाते'
  },
  'te': {
    'name': 'తెలుగు',
    'login': 'లాగిన్',
    'signup': 'ఖాతా సృష్టించండి',
    'language': 'భాష',
    'account': 'ఖాతా'
  },
  'tr': {
    'name': 'Türkçe',
    'login': 'Giriş yap',
    'signup': 'Hesap oluştur',
    'language': 'Dil',
    'account': 'Hesap',
    'ranking': 'Sıralama',
    'simulator': 'Simülatör',
    'invite': 'Arkadaşlarını davet et',
    'email': 'E-posta',
    'password': 'Şifre',
    'share': 'Paylaş',
    'logout': 'Çıkış yap',
    'copy': 'Bağlantımı kopyala',
    'confirm': 'Kodu onayla',
    'welcome': 'THE GENESIS ERA\'ya hoş geldiniz'
  },
  'ta': {
    'name': 'தமிழ்',
    'login': 'உள்நுழை',
    'signup': 'கணக்கு உருவாக்கு',
    'language': 'மொழி',
    'account': 'கணக்கு'
  },
  'vi': {
    'name': 'Tiếng Việt',
    'login': 'Đăng nhập',
    'signup': 'Tạo tài khoản',
    'language': 'Ngôn ngữ',
    'account': 'Tài khoản'
  },
  'ko': {
    'name': '한국어',
    'login': '로그인',
    'signup': '계정 만들기',
    'language': '언어',
    'account': '계정'
  },
  'it': {
    'name': 'Italiano',
    'login': 'Accedi',
    'signup': 'Crea un account',
    'language': 'Lingua',
    'account': 'Account',
    'ranking': 'Classifica',
    'simulator': 'Simulatore',
    'invite': 'Invita amici',
    'email': 'E-mail',
    'password': 'Password',
    'share': 'Condividi',
    'logout': 'Esci',
    'copy': 'Copia il mio link',
    'confirm': 'Conferma codice',
    'welcome': 'Benvenuto in THE GENESIS ERA'
  },
  'th': {
    'name': 'ไทย',
    'login': 'เข้าสู่ระบบ',
    'signup': 'สร้างบัญชี',
    'language': 'ภาษา',
    'account': 'บัญชี'
  },
  'gu': {
    'name': 'ગુજરાતી',
    'login': 'લૉગ ઇન',
    'signup': 'ખાતું બનાવો',
    'language': 'ભાષા',
    'account': 'ખાતું'
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
  },
  'uk': {
    'name': 'Українська',
    'login': 'Увійти',
    'signup': 'Створити акаунт',
    'language': 'Мова',
    'account': 'Обліковий запис',
    'ranking': 'Рейтинг',
    'simulator': 'Симулятор',
    'invite': 'Запросити друзів',
    'email': 'Ел. пошта',
    'password': 'Пароль',
    'share': 'Поділитися',
    'logout': 'Вийти',
    'copy': 'Скопіювати посилання',
    'confirm': 'Підтвердити код',
    'welcome': 'Ласкаво просимо до THE GENESIS ERA'
  },
  'fa': {
    'name': 'فارسی',
    'login': 'ورود',
    'signup': 'ایجاد حساب',
    'language': 'زبان',
    'account': 'حساب'
  },
  'pa': {
    'name': 'ਪੰਜਾਬੀ',
    'login': 'ਲੌਗ ਇਨ',
    'signup': 'ਖਾਤਾ ਬਣਾਓ',
    'language': 'ਭਾਸ਼ਾ',
    'account': 'ਖਾਤਾ'
  },
  'ro': {
    'name': 'Română',
    'login': 'Autentificare',
    'signup': 'Creează cont',
    'language': 'Limbă',
    'account': 'Cont'
  },
  'nl': {
    'name': 'Nederlands',
    'login': 'Inloggen',
    'signup': 'Account aanmaken',
    'language': 'Taal',
    'account': 'Account'
  },
  'hu': {
    'name': 'Magyar',
    'login': 'Bejelentkezés',
    'signup': 'Fiók létrehozása',
    'language': 'Nyelv',
    'account': 'Fiók'
  },
  'el': {
    'name': 'Ελληνικά',
    'login': 'Σύνδεση',
    'signup': 'Δημιουργία λογαριασμού',
    'language': 'Γλώσσα',
    'account': 'Λογαριασμός'
  },
  'cs': {
    'name': 'Čeština',
    'login': 'Přihlásit se',
    'signup': 'Vytvořit účet',
    'language': 'Jazyk',
    'account': 'Účet'
  },
  'sv': {
    'name': 'Svenska',
    'login': 'Logga in',
    'signup': 'Skapa konto',
    'language': 'Språk',
    'account': 'Konto'
  },
  'fi': {
    'name': 'Suomi',
    'login': 'Kirjaudu',
    'signup': 'Luo tili',
    'language': 'Kieli',
    'account': 'Tili'
  },
  'he': {
    'name': 'עברית',
    'login': 'התחברות',
    'signup': 'יצירת חשבון',
    'language': 'שפה',
    'account': 'חשבון'
  },
  'da': {
    'name': 'Dansk',
    'login': 'Log ind',
    'signup': 'Opret konto',
    'language': 'Sprog',
    'account': 'Konto'
  },
  'no': {
    'name': 'Norsk',
    'login': 'Logg inn',
    'signup': 'Opprett konto',
    'language': 'Språk',
    'account': 'Konto'
  },
  'sk': {
    'name': 'Slovenčina',
    'login': 'Prihlásiť sa',
    'signup': 'Vytvoriť účet',
    'language': 'Jazyk',
    'account': 'Účet'
  },
  'bg': {
    'name': 'Български',
    'login': 'Вход',
    'signup': 'Създай акаунт',
    'language': 'Език',
    'account': 'Акаунт'
  },
  'sr': {
    'name': 'Српски',
    'login': 'Пријави се',
    'signup': 'Направи налог',
    'language': 'Језик',
    'account': 'Налог'
  },
  'hr': {
    'name': 'Hrvatski',
    'login': 'Prijava',
    'signup': 'Izradi račun',
    'language': 'Jezik',
    'account': 'Račun'
  },
  'ms': {
    'name': 'Bahasa Melayu',
    'login': 'Log masuk',
    'signup': 'Cipta akaun',
    'language': 'Bahasa',
    'account': 'Akaun'
  },
  'fil': {
    'name': 'Filipino',
    'login': 'Mag-log in',
    'signup': 'Gumawa ng account',
    'language': 'Wika',
    'account': 'Account'
  },
  'my': {
    'name': 'မြန်မာ',
    'login': 'ဝင်ရန်',
    'signup': 'အကောင့်ဖွင့်ရန်',
    'language': 'ဘာသာစကား',
    'account': 'အကောင့်'
  },
  'am': {
    'name': 'አማርኛ',
    'login': 'ግባ',
    'signup': 'መለያ ፍጠር',
    'language': 'ቋንቋ',
    'account': 'መለያ'
  },
  'ne': {
    'name': 'नेपाली',
    'login': 'लग इन',
    'signup': 'खाता बनाउनुहोस्',
    'language': 'भाषा',
    'account': 'खाता'
  },
  'si': {
    'name': 'සිංහල',
    'login': 'ඇතුළු වන්න',
    'signup': 'ගිණුමක් සාදන්න',
    'language': 'භාෂාව',
    'account': 'ගිණුම'
  },
  'km': {
    'name': 'ខ្មែរ',
    'login': 'ចូល',
    'signup': 'បង្កើតគណនី',
    'language': 'ភាសា',
    'account': 'គណនី'
  },
  'uz': {
    'name': 'Oʻzbekcha',
    'login': 'Kirish',
    'signup': 'Hisob yaratish',
    'language': 'Til',
    'account': 'Hisob'
  },
  'ha': {
    'name': 'Hausa',
    'login': 'Shiga',
    'signup': 'Ƙirƙiri asusu',
    'language': 'Harshe',
    'account': 'Asusu'
  }
};
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

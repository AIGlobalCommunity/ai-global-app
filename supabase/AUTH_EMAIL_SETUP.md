# Konfiguracja aktywacji kont AGC (Supabase)

Projekt: `gjnddmurmegbklvedhnp`
Publiczny adres aplikacji: `https://aiglobalcommunity.github.io/ai-global-app/`

## 1. Authentication → URL Configuration
- **Site URL**: `https://aiglobalcommunity.github.io/ai-global-app/` (NIE `http://localhost:3000`)
- **Redirect URLs**: dodaj `https://aiglobalcommunity.github.io/ai-global-app/`
- W środowisku lokalnym można dodatkowo dodać localhost, ale nie używać go jako Site URL produkcji.

## 2. Authentication → Email Templates → Confirm signup
- **Subject**: `Witaj w Genesis — potwierdź konto w AI Global Community`
- Wklej HTML z `supabase/email_templates/confirm_signup_pl.html`.
- **Ważne:** w szablonie musi być `{{ .ConfirmationURL }}`, a nie sztywne `localhost:3000` ani `{{ .SiteURL }}` użyte jako link aktywacyjny.
- Zapisz szablon i wyślij **nowy** e-mail aktywacyjny poprzez nową rejestrację; poprzednie tokeny nie zadziałają ponownie.

## 3. Test
Zarejestruj nowy adres, otwórz najnowszy e-mail i sprawdź, czy po kliknięciu przeglądarka wraca do `https://aiglobalcommunity.github.io/ai-global-app/`.
Komunikat `otp_expired` oznacza przeterminowany, wykorzystany lub nieważny token i wymaga nowego linku.

**Uwaga:** HTML szablonu jest zapisany w repozytorium; sam commit GitHub **nie zmienia** szablonu w panelu Supabase. URL Configuration i Email Templates trzeba ustawić w panelu Supabase z uprawnieniami administratora.

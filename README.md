# GastroConnect — Android-приложение

WebView-оболочка сайта [gastroconnect.ru](https://gastroconnect.ru/).

## Сборка

Сборка идёт автоматически через GitHub Actions при каждом пуше в `main`.
Готовый APK появляется в разделе **Releases** этого репозитория.

Локальная сборка:

```
gradle assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## Установка на телефон

1. Скачайте APK из Releases.
2. Разрешите установку из неизвестных источников (запрос появится автоматически).
3. Установите и откройте — приложение показывает сайт gastroconnect.ru (вход по email и Telegram работает внутри приложения).
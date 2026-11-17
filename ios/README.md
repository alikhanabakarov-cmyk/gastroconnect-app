# GastroConnect для iOS

Нативная обёртка (Swift + WKWebView) вокруг продакшн-сайта **https://gastroconnect.ru/** — то же
приложение, что и Android-версия, но для iPhone.

Внутри: загрузка файлов (фото, PDF), скачивание файлов с шарингом, открытие внешних ссылок
(Telegram, почта, телефон) в системных приложениях, индикатор загрузки, pull-to-refresh и экран
«Нет подключения» с кнопкой «Повторить».

## Что уже готово

| Файл | Назначение |
| --- | --- |
| `GastroConnect/AppDelegate.swift` | Точка входа, конфигурация сцены |
| `GastroConnect/SceneDelegate.swift` | Создание окна, обработка открытия по ссылке |
| `GastroConnect/WebViewController.swift` | WebView, файлы, ссылки, загрузки, ошибки |
| `GastroConnect/Info.plist` | Portrait-only, без шифрования (`ITSAppUsesNonExemptEncryption=false`) |
| `GastroConnect/PrivacyInfo.xcprivacy` | Privacy Manifest для App Store |
| `GastroConnect/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | Иконка 1024×1024 без альфы |
| `project.yml` | Спецификация проекта для XcodeGen |

Bundle ID: `ru.gastroconnect.app`. Версия: `1.0.0 (1)`. Минимальная iOS: **15.0**, только iPhone.

## Сборка на Mac

```bash
brew install xcodegen
cd ios
xcodegen generate
open GastroConnect.xcodeproj
```

В Xcode: выбрать свою команду в *Signing & Capabilities* (нужен Apple ID, добавленный в Xcode),
подключить iPhone и нажать Run. Для симулятора подпись не нужна.

Проверка сборки без Mac-аккаунта разработчика уже автоматизирована:
`.github/workflows/build-ios.yml` собирает приложение на macOS-раннере GitHub Actions
(`workflow_dispatch` или любой push в `ios/**`). Артефакт — неподписанный `GastroConnect.app`,
он нужен только для проверки, что код компилируется.

## Публикация в App Store

1. **Apple Developer Program** — 99 $/год, регистрация: https://developer.apple.com/programs/
   (для личного аккаунта нужен паспорт и подтверждение личности).
2. В App Store Connect создать приложение:
   - название: `GastroConnect — работа в HoReCa` (до 30 символов, иначе сократить до `GastroConnect`);
   - Bundle ID: `ru.gastroconnect.app`;
   - SKU: `gastroconnect-ios`;
   - основной язык: русский.
3. Загрузить сборку через Xcode (*Product → Archive → Distribute App*) или `xcrun altool`.
   Для CI можно добавить секреты `APPLE_TEAM_ID`, `APPSTORE_API_KEY_ID`,
   `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_PRIVATE_KEY` и шаг `xcodebuild -exportArchive`.
4. Заполнить карточку:
   - категория: «Бизнес»;
   - возрастной рейтинг: 12+;
   - конфиденциальность: те же 7 типов данных, что и в `PrivacyInfo.xcprivacy`;
   - скриншоты 1290×2796 (6.7") и 1179×2556 (6.1") — можно взять те же макеты, что для RuStore,
     но в размерах iPhone (например, 1179×2556);
   - описание, ключевые слова и промо-текст — в `../store/ТЕКСТЫ-ДЛЯ-МАГАЗИНОВ.md`.
5. Отправить на проверку. Первая проверка обычно 1–3 дня.

## Универсальные ссылки (после регистрации в Apple Developer)

Чтобы ссылки `https://gastroconnect.ru/...` открывались в приложении:

1. Включить capability **Associated Domains** → `applinks:gastroconnect.ru`.
2. Положить на сайт `https://gastroconnect.ru/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "details": [{ "appIDs": ["TEAMID.ru.gastroconnect.app"], "components": [{ "/": "*" }] }]
  }
}
```

3. Добавить в `SceneDelegate` обработку `NSUserActivity` (`NSUserActivityTypeBrowsingWeb`) —
   метод `scene(_:continue:)` с загрузкой `activity.webpageURL` через `WebViewController.load(_:)`.

## Обновление версии

В `project.yml` менять `MARKETING_VERSION` и `CURRENT_PROJECT_VERSION` (в App Store номер сборки
должен расти), затем повторить Archive → Upload.

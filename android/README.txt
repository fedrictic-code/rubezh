APK «РУБЕЖ» (оболочка WebView)
==============================

Что внутри: обычный Android-проект. Он открывает игру (android/app/src/main/assets/www/index.html)
в полноэкранном WebView, альбомная ориентация, экран не гаснет.

Способ 1. Автосборка на GitHub (ничего ставить не надо)
  1. Загрузите всю папку Rubezh в свой репозиторий (ветка main), вместе с папками
     .github, android, src, art и файлами build.py, .gitignore.
  2. Откройте репозиторий, вкладка Actions, запуск «Сборка APK» (запускается сам после загрузки,
     или кнопка Run workflow).
  3. Через 5-10 минут откройте завершённый запуск, внизу раздел Artifacts, скачайте rubezh-apk.
     Внутри app-debug.apk. Перекиньте на телефон и установите (разрешите установку из неизвестных источников).

Способ 2. Android Studio
  1. Запустите build.bat (или python build.py): игра скопируется в android/app/src/main/assets/www/.
  2. Откройте папку android в Android Studio, дождитесь синхронизации.
  3. Build, Build Bundle(s) / APK(s), Build APK(s). Файл: android/app/build/outputs/apk/debug/app-debug.apk

После добавления картинок в art/ всегда заново запускайте build.py (в GitHub это делает автосборка).

Это debug-сборка с отладочной подписью: для личной проверки на телефоне подходит, для публикации
в магазине нужна release-подпись (потом).

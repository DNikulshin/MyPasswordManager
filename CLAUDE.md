# CLAUDE.md — Контекст проекта MyPasswordManager

> Файл содержит полный контекст проекта для будущих сессий AI.
> Обновляется при значимых изменениях (решения, новые фичи, баги, изменения архитектуры).

---

## Цель

Локальный менеджер паролей для Windows на PowerShell 5.1+, работающий из системного трея с глобальной горячей клавишей для автозаполнения логинов/паролей в любое приложение. Без внешних зависимостей — только PowerShell и .NET Framework 4.8.

Целевая аудитория: один пользователь на своей Windows-машине, хранит пароли локально, не хочет ставить сторонний софт.

---

## Общее описание

- Приложение работает в системном трее, иконка с контекстным меню.
- Хранилище паролей зашифровано AES-256 (через `ConvertFrom-SecureString` с ключом из мастер-пароля, SHA-256).
- Конфигурация горячей клавиши — в отдельном JSON-файле.
- GUI на WPF (главное окно) + Windows Forms (вход, настройки, выбор сервиса).
- Автозаполнение — через `SendKeys` (см. нюансы).

---

## Структура проекта

```
MyPM/
├── Main.ps1              # Точка входа, трей, горячие клавиши, Invoke-PasswordFill
├── Vault.ps1             # Класс PasswordVault (шифрование + config)
├── Gui.ps1               # Show-LoginWindow / Show-MainWindow / Show-SettingsWindow
├── HotkeyManager.ps1     # Класс KeyboardHook (WinAPI RegisterHotKey)
├── InputSimulator.ps1    # Класс InputSimulator (SendInput, пока не используется)
├── Install.ps1           # Установка в автозагрузку + Launcher.vbs
├── Uninstall.ps1         # Удаление из автозагрузки + очистка
├── Launcher.vbs          # Скрытый запуск PowerShell (создаётся Install.ps1)
├── MyPM.lnk              # Ярлык
├── icon.ico              # Иконка трея
├── CLAUDE.md             # Этот файл
├── README.md             # Документация для пользователей
└── .gitignore            # Исключения (.env, *.zip, *.secure, config.json)
```

---

## Основные компоненты

### Main.ps1 — точка входа
- Скрывает консоль (WinAPI `ShowWindow` с `SW_HIDE`).
- Проверяет единственный экземпляр через `Mutex`.
- Запрашивает мастер-пароль через `Show-LoginWindow`.
- Инициализирует `$script:Vault = [PasswordVault]::new(...)`.
- Загружает конфиг горячей клавиши через `[PasswordVault]::LoadConfig()`.
- Регистрирует глобальную горячую клавишу (`KeyboardHook`).
- Создаёт `NotifyIcon` в трее с контекстным меню.
- Запускает `[System.Windows.Forms.Application]::Run()`.

**Ключевые функции:**
- `Invoke-PasswordFill` — открывает окно выбора сервиса, вставляет логин+TAB+пароль или только пароль (чекбокс «Только пароль»). Использует `SendKeys.SendWait`.
- `Update-Hotkey` — колбэк, перерегистрирует горячую клавишу без перезапуска (вызывается из настроек GUI).

### Vault.ps1 — класс PasswordVault
- Хранилище: `%USERPROFILE%\.my_pm\data.secure` (AES-256).
- Методы экземпляра: `SaveEntry`, `GetEntry`, `ListServices`, `RemoveEntry`, `Validate()`.
- `Validate()` расшифровывает тестовую запись `__validation__` для проверки мастер-пароля.
- Статические методы (добавлены 2026-04-23): `LoadConfig()` / `SaveConfig($config)` — работа с `config.json`. По умолчанию возвращают Ctrl+Shift+P.

### Gui.ps1 — графический интерфейс
- `Show-LoginWindow` — вход (Windows Forms), поддержка «Показать пароль», ссылка «Забыли пароль?».
- `Show-MainWindow` — главное окно WPF: список записей, поиск, добавление, удаление, кнопка ⚙ (настройки). Принимает колбэк `OnHotkeyChanged`.
- `Show-SettingsWindow` (добавлено 2026-04-23) — Windows Forms, выбор модификаторов Ctrl/Shift/Alt и клавиши (A–Z, D0–D9, F1–F12).
- Поиск — фильтрация таблицы в реальном времени.
- При добавлении — временный показ пароля по чекбоксу.
- При удалении — диалог подтверждения.

### HotkeyManager.ps1
- Класс `KeyboardHook` (наследует `NativeWindow`), WinAPI `RegisterHotKey`.
- Событие `HotkeyPressed` (тип `Action`).
- Корректный `Dispose()`.

### InputSimulator.ps1
- Класс `InputSimulator.SendText` через WinAPI `SendInput`.
- Функция `Send-SecureString`.
- **Не используется в рантайме** — оставлен для будущих улучшений (см. Нюансы).

### Install.ps1 / Uninstall.ps1
- Install: создаёт `Launcher.vbs` (скрытый запуск), пишет `HKCU:\...\Run`.
- Uninstall: убирает автозагрузку, спрашивает про удаление хранилища, самоудаляется через cmd.

---

## Хранилище и конфигурация

**Хранилище паролей:** `%USERPROFILE%\.my_pm\data.secure`
- AES-256, ключ = SHA-256 от мастер-пароля.
- Содержит тестовую запись `__validation__`.

**Конфигурация:** `%USERPROFILE%\.my_pm\config.json`
```json
{
  "HotkeyModifiers": { "Ctrl": true, "Shift": true, "Alt": false },
  "HotkeyKey": "P"
}
```

---

## Принятые решения (с датами)

### 2026-04-23 — Настраиваемая горячая клавиша
- Добавлены `[PasswordVault]::LoadConfig()` / `SaveConfig()` — хранение в `config.json`.
- Добавлено окно `Show-SettingsWindow` + кнопка ⚙ в главном окне.
- В `Main.ps1` выделены `Invoke-PasswordFill` (логика вставки) и `Update-Hotkey` (колбэк перерегистрации).
- Горячая клавиша меняется на лету, без перезапуска приложения.

### 2026-04-23 — Безопасность репозитория
- Добавлен `.gitignore`: исключены `.env`, `*.zip`, `*.secure`, `config.json`, системные файлы.
- Причина: в корне лежал `.env` с GitHub PAT — нельзя допустить коммит.

### Ранее (до 2026-04-23)
- `SendKeys` выбран вместо `SendInput` для автозаполнения — совместимость с большим числом приложений (см. Нюансы).
- Мастер-пароль не хранится; при утере — полный сброс хранилища через «Забыли пароль?».
- VBS-лаунчер для полного скрытия окна PowerShell при автозапуске.

---

## Что сделано

- ✅ Ядро: класс `PasswordVault`, шифрование AES-256, проверка через `__validation__`.
- ✅ GUI: вход, главное окно (WPF), добавление/удаление/поиск/показ пароля, подтверждение удаления.
- ✅ Трей-иконка с контекстным меню.
- ✅ Глобальная горячая клавиша через `KeyboardHook`.
- ✅ Автозаполнение (логин+TAB+пароль или только пароль).
- ✅ Установка/удаление через `Install.ps1` / `Uninstall.ps1` + VBS-лаунчер.
- ✅ Единственный экземпляр через `Mutex`.
- ✅ **Настраиваемая горячая клавиша** (2026-04-23).
- ✅ **`.gitignore` и безопасность репо** (2026-04-23).

---

## Что осталось / идеи на будущее

- [ ] Переход на `SendInput` (`InputSimulator.ps1` уже готов) — после решения проблем совместимости.
- [ ] Импорт/экспорт хранилища (для переноса между ПК).
- [ ] Генератор паролей (в окне добавления).
- [ ] Автоблокировка по таймауту бездействия.
- [ ] Скриншоты в `screenshots/` (README ссылается, но папки нет).
- [ ] Лицензионный файл `LICENSE` (README упоминает MIT).
- [ ] Тесты (Pester) — сейчас отсутствуют.

---

## Нюансы / баги / обходные пути

### SendKeys vs SendInput
- Автозаполнение использует `System.Windows.Forms.SendKeys.SendWait`, а не `SendInput` из `InputSimulator.ps1`.
- **Причина:** `SendInput` не работал стабильно в некоторых приложениях (UWP, повышенные привилегии).
- **Побочный эффект:** `SendKeys` игнорируется Блокнотом и примитивными контролами. В браузерах и большинстве окон работает.
- Код `InputSimulator` сохранён на будущее.

### Задержки в `Invoke-PasswordFill`
- `Start-Sleep -Milliseconds 300` перед вставкой — чтобы фокус успел вернуться в целевое окно после закрытия диалога выбора.
- `Start-Sleep -Milliseconds 50` между логином, TAB и паролем — чтобы приложение успело обработать переход фокуса.

### Конфликт горячих клавиш
- `RegisterHotKey` может упасть, если сочетание уже занято другим приложением.
- Обработка: `MessageBox` с предупреждением, `$script:hook = $null`, автозаполнение недоступно до смены клавиши через настройки.

### Области видимости ($script:)
- `$script:hook` и `$script:Vault` должны использоваться консистентно в `Main.ps1` и функциях `Invoke-PasswordFill` / `Update-Hotkey`. Раньше путались `$hook` vs `$script:hook` — исправлено 2026-04-23.

### Сброс пароля
- «Забыли пароль?» удаляет файл `data.secure` целиком — старые данные не восстанавливаются.
- После сброса цикл входа возобновляется с нуля (новый мастер-пароль).

---

## Git и репозиторий

- **Remote:** `https://github.com/DNikulshin/MyPasswordManager.git`
- **Username:** `DNikulshin`
- **Ветка:** `main`
- **Auth:** в `.env` лежит `SSh_GITHUB_KEY` — это **GitHub Personal Access Token** (префикс `ghp_`), несмотря на название. SSH-ключей не настроено.
- **Пуш:** `source .env && git push "https://DNikulshin:${SSh_GITHUB_KEY}@github.com/DNikulshin/MyPasswordManager.git" main`
- **`.env` в `.gitignore`** — никогда не коммитить.
- При выводе команд с токеном — редактировать через `sed 's/ghp_[A-Za-z0-9]*/ghp_***REDACTED***/g'`.

### История сессии 2026-04-23
1. Распакован `MyPM.zip` с обновлениями, сравнён с текущим проектом.
2. Обновлены `Main.ps1`, `Vault.ps1`, `Gui.ps1`, `README.md`, добавлен `CLAUDE.md`.
3. 5 атомарных коммитов запушены на GitHub:
   - `feat(Vault): LoadConfig/SaveConfig`
   - `feat(Gui): Show-SettingsWindow + кнопка ⚙`
   - `refactor(Main): Invoke-PasswordFill / Update-Hotkey`
   - `docs: CLAUDE.md + README`
   - `chore: .gitignore`

---

## Требования

- Windows 10 / 11 (теоретически 7 с PS 5.1).
- PowerShell 5.1+.
- .NET Framework 4.8.
- `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` перед первым запуском.

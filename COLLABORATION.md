# Совместная разработка

## Начало задачи

```powershell
git fetch --prune origin
git switch main
git pull --ff-only
git switch -c feature/короткое-название
```

Если ветка уже существует:

```powershell
git switch feature/короткое-название
git merge origin/main
```

Перед переключением ветки `git status` должен быть понятным: изменения нужно либо закоммитить в своей ветке, либо временно сохранить через именованный `git stash push -u -m "описание"`.

## Завершение задачи

```powershell
git status --short
git diff
git add <только-нужные-файлы>
git commit -m "тип: краткое описание"
git push -u origin HEAD
gh pr create --base main --fill
```

Перед объединением Pull Request обновить ветку из `origin/main`, разрешить конфликты вручную и повторно проверить Godot-проект. Не использовать force-push и не собирать Release без отдельного согласования.

## Разделение работы

- Один разработчик не редактирует одновременно с другим одну и ту же крупную `.tscn`-сцену.
- Сцены, скрипты, интерфейс, звук и баланс по возможности распределяются по отдельным веткам и файлам.
- Машинный кэш `godot/.godot/` никогда не коммитится.
- Массовые изменения `.import` коммитятся только когда импорт ассетов менялся намеренно.

## Сборка и обновления

Сборку никто не выкладывает руками. Как только Pull Request влит в `main`, GitHub сам собирает .exe и обновляет релиз `godot-build` (файл `.github/workflows/godot-build.yml`). Ссылка на игру всегда одна — её можно кидать кому угодно:

https://github.com/jelos8vetoi/god-of-grimerka/releases/tag/godot-build

Друзьям проще всего кинуть лаунчер — его качают один раз, дальше он сам обновляет игру: https://github.com/jelos8vetoi/god-of-grimerka/releases/download/godot-build/GOD-OF-GRIMERKA-Launcher.exe

- Лаунчер — `tools/launcher/Launcher.cs` (C#, собирается встроенным в Windows компилятором .NET Framework через `tools/launcher/build.cmd`). Автосборка собирает его и кладёт в тот же релиз.

- Перед Pull Request допиши сверху в `godot/CHANGELOG.md` раздел `## дата · что сделано` — этот текст станет описанием релиза.
- Музыка в git не лежит: её создаёт `node tools/godot-music.cjs` (нужен Node.js). `play-godot.cmd` запускает его сам при первом запуске.
- Ход сборки видно во вкладке Actions репозитория. Запустить её вручную: Actions → «Godot-сборка» → Run workflow.
- В меню игры появляется кнопка «Вышло обновление», если на GitHub лежит сборка новее.


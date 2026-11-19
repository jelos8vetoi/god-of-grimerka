// Лаунчер GOD OF GRIMERKA: скачивается один раз, дальше сам держит игру свежей.
// 1. Спрашивает у GitHub релиз godot-build.
// 2. Если вышел новый лаунчер — тихо подменяет себя и перезапускается.
// 3. Если игра не установлена или на GitHub лежит другая сборка — скачивает её
//    в %LOCALAPPDATA%\GOD OF GRIMERKA\ с прогрессом и проверкой SHA-256.
// 4. Запускает игру и закрывается. Без сети — запускает то, что уже установлено.
// Собирается компилятором .NET Framework 4 (есть в любой Windows 10/11), см. tools/launcher/build.cmd.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("GOD OF GRIMERKA — лаунчер")]
[assembly: System.Reflection.AssemblyProduct("GOD OF GRIMERKA")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

static class Program
{
	[STAThread]
	static void Main(string[] args)
	{
		FastDownload.Setup();
		Application.EnableVisualStyles();
		Application.SetCompatibleTextRenderingDefault(false);
		Application.Run(new LauncherForm(args));
	}
}

class LauncherForm : Form
{
	const string Api = "https://api.github.com/repos/jelos8vetoi/god-of-grimerka/releases/tags/godot-build";
	const string Page = "https://github.com/jelos8vetoi/god-of-grimerka/releases/tag/godot-build";
	const string GameAsset = "GOD-OF-GRIMERKA-Godot.exe";
	const string LauncherAsset = "GOD-OF-GRIMERKA-Launcher.exe";
	const string UserAgent = "god-of-grimerka-launcher";

	string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GOD OF GRIMERKA Godot");   // "GOD OF GRIMERKA" занята старым лаунчером браузерной версии
	readonly string self = Application.ExecutablePath;
	readonly bool noSelfUpdate;
	readonly bool checkOnly;
	string GameExe { get { return Path.Combine(dir, "GOD OF GRIMERKA.exe"); } }
	string StampFile { get { return Path.Combine(dir, "installed.txt"); } }

	readonly Label status = new Label();
	readonly Label detail = new Label();
	readonly ProgressBar bar = new ProgressBar();
	readonly Button retry = new Button();
	readonly Button page = new Button();
	readonly Color bg = Color.FromArgb(18, 18, 24);
	readonly Color fg = Color.FromArgb(232, 232, 240);
	readonly Color dim = Color.FromArgb(150, 152, 170);

	public LauncherForm(string[] args)
	{
		// поставлен установщиком (рядом лежит его метка) — игра живёт в той же папке, что и лаунчер
		if (File.Exists(Path.Combine(Path.GetDirectoryName(self), "grimerka-install.txt")))
			dir = Path.GetDirectoryName(self);
		foreach (string a in args)
		{
			if (a == "--no-self-update") noSelfUpdate = true;
			if (a == "--check-only") checkOnly = true;   // для проверки: всё, кроме запуска игры
		}
		Text = "GOD OF GRIMERKA";
		FormBorderStyle = FormBorderStyle.FixedSingle;
		MaximizeBox = false;
		StartPosition = FormStartPosition.CenterScreen;
		ClientSize = new Size(480, 190);
		BackColor = bg;
		try { Icon = Icon.ExtractAssociatedIcon(self); } catch { }

		Label title = new Label();
		title.Text = "GOD OF GRIMERKA";
		title.Font = new Font("Segoe UI", 20f, FontStyle.Bold);
		title.ForeColor = Color.FromArgb(255, 196, 60);
		title.AutoSize = true;
		title.Location = new Point(22, 16);
		Controls.Add(title);

		status.Font = new Font("Segoe UI", 11f);
		status.ForeColor = fg;
		status.Location = new Point(24, 70);
		status.Size = new Size(432, 24);
		status.Text = "Проверяю обновления…";
		Controls.Add(status);

		bar.Location = new Point(24, 100);
		bar.Size = new Size(432, 14);
		bar.Style = ProgressBarStyle.Marquee;
		Controls.Add(bar);

		detail.Font = new Font("Segoe UI", 9f);
		detail.ForeColor = dim;
		detail.Location = new Point(24, 120);
		detail.Size = new Size(432, 20);
		Controls.Add(detail);

		retry.Text = "Повторить";
		retry.Location = new Point(24, 148);
		retry.Size = new Size(120, 30);
		retry.FlatStyle = FlatStyle.Flat;
		retry.ForeColor = fg;
		retry.Visible = false;
		retry.Click += delegate { retry.Visible = false; page.Visible = false; Start(); };
		Controls.Add(retry);

		page.Text = "Страница игры";
		page.Location = new Point(152, 148);
		page.Size = new Size(140, 30);
		page.FlatStyle = FlatStyle.Flat;
		page.ForeColor = fg;
		page.Visible = false;
		page.Click += delegate { Process.Start(Page); };
		Controls.Add(page);

		Shown += delegate { Start(); };
	}

	void Start()
	{
		Thread t = new Thread(Work);
		t.IsBackground = true;
		t.Start();
	}

	void Ui(Action a)
	{
		if (IsDisposed) return;
		try { BeginInvoke(a); } catch { }
	}

	void Say(string s, string d)
	{
		Ui(delegate { status.Text = s; detail.Text = d ?? ""; });
	}

	void Work()
	{
		Directory.CreateDirectory(dir);
		Dictionary<string, object> rel = null;
		try
		{
			rel = FetchRelease();
		}
		catch (Exception e)
		{
			Offline("Нет связи с GitHub", e.Message);
			return;
		}
		try
		{
			Dictionary<string, object> launcher = FindAsset(rel, LauncherAsset);
			if (!noSelfUpdate && launcher != null && SelfUpdate(launcher))
				return;
			Dictionary<string, object> game = FindAsset(rel, GameAsset);
			if (game == null)
			{
				Offline("В релизе нет файла игры", "Похоже, сборка обновляется прямо сейчас — попробуй через пару минут.");
				return;
			}
			string want = Stamp(game);
			string have = File.Exists(StampFile) ? File.ReadAllText(StampFile).Trim() : "";
			if (!File.Exists(GameExe) || have != want)
			{
				if (IsGameRunning())
				{
					Fail("Игра запущена", "Закрой игру, чтобы лаунчер её обновил.");
					return;
				}
				Download(game);
				File.WriteAllText(StampFile, want);
			}
			Launch(File.Exists(GameExe) && have == want ? "Последняя версия, запускаю…" : "Игра обновлена, запускаю…");
		}
		catch (Exception e)
		{
			Offline("Не удалось обновить", e.Message);
		}
	}

	// ---------- GitHub ----------
	Dictionary<string, object> FetchRelease()
	{
		HttpWebRequest r = (HttpWebRequest)WebRequest.Create(Api);
		r.UserAgent = UserAgent;
		r.Accept = "application/vnd.github+json";
		r.Timeout = 15000;
		using (WebResponse resp = r.GetResponse())
		using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
		{
			JavaScriptSerializer js = new JavaScriptSerializer();
			js.MaxJsonLength = int.MaxValue;
			return js.Deserialize<Dictionary<string, object>>(sr.ReadToEnd());
		}
	}

	static Dictionary<string, object> FindAsset(Dictionary<string, object> rel, string name)
	{
		object list;
		if (!rel.TryGetValue("assets", out list)) return null;
		foreach (object o in (ArrayList)list)
		{
			Dictionary<string, object> a = o as Dictionary<string, object>;
			if (a != null && Convert.ToString(a["name"]) == name) return a;
		}
		return null;
	}

	static string Get(Dictionary<string, object> a, string key)
	{
		object v;
		return a.TryGetValue(key, out v) && v != null ? Convert.ToString(v) : "";
	}

	// Версия файла в релизе: SHA-256 от GitHub, если он его сообщает, иначе номер файла и время загрузки.
	static string Stamp(Dictionary<string, object> a)
	{
		string digest = Get(a, "digest");
		if (digest.StartsWith("sha256:")) return digest;
		return "id:" + Get(a, "id") + "@" + Get(a, "updated_at");
	}

	static string Sha256(string path)
	{
		using (SHA256 h = SHA256.Create())
		using (FileStream f = File.OpenRead(path))
		{
			byte[] b = h.ComputeHash(f);
			StringBuilder sb = new StringBuilder("sha256:");
			foreach (byte x in b) sb.Append(x.ToString("x2"));
			return sb.ToString();
		}
	}

	// ---------- скачивание ----------
	void DownloadTo(Dictionary<string, object> asset, string target, string what)
	{
		string url = Get(asset, "browser_download_url");
		long size = Convert.ToInt64(asset["size"]);
		string part = target + ".part";
		Ui(delegate { bar.Style = ProgressBarStyle.Continuous; bar.Value = 0; });
		DateTime t0 = DateTime.Now;
		long shownAt = 0;
		object gate = new object();
		// сразу несколько частей параллельно (FastDownload.cs); прогресс приходит из всех потоков
		FastDownload.Get(url, part, size, UserAgent, delegate (long done)
		{
			long now = DateTime.Now.Ticks;
			lock (gate)
			{
				if (now - shownAt < 1200000 && done != size) return;     // не чаще раза в 120 мс
				shownAt = now;
			}
			double sec = Math.Max(0.1, (DateTime.Now - t0).TotalSeconds);
			int pct = size > 0 ? (int)(done * 100 / size) : 0;
			double mbs = done / 1048576.0 / sec;
			double left = mbs > 0.01 ? (size - done) / 1048576.0 / mbs : 0;
			string d = string.Format("{0:0} из {1:0} МБ · {2:0.0} МБ/с · осталось ~{3}", done / 1048576.0, size / 1048576.0, mbs, TimeLeft(left));
			Ui(delegate { bar.Value = Math.Min(100, pct); detail.Text = d; });
		}, null);
		if (new FileInfo(part).Length != size)
			throw new Exception(what + ": файл скачался не полностью");
		string digest = Get(asset, "digest");
		if (digest.StartsWith("sha256:"))
		{
			Say("Проверяю файл…", what);
			if (Sha256(part) != digest)
			{
				File.Delete(part);
				throw new Exception(what + ": контрольная сумма не совпала, скачай ещё раз");
			}
		}
		if (File.Exists(target)) File.Delete(target);
		File.Move(part, target);
	}

	static string TimeLeft(double sec)
	{
		if (sec < 60) return Math.Max(1, (int)sec) + " с";
		return (int)(sec / 60) + " мин " + ((int)sec % 60) + " с";
	}

	void Download(Dictionary<string, object> game)
	{
		Say(File.Exists(GameExe) ? "Скачиваю обновление…" : "Скачиваю игру…", "");
		DownloadTo(game, GameExe, "игра");
	}

	// Новый лаунчер: скачать рядом, дождаться выхода этого и подменить файл маленьким сценарием.
	bool SelfUpdate(Dictionary<string, object> asset)
	{
		string digest = Get(asset, "digest");
		if (!digest.StartsWith("sha256:") || Sha256(self) == digest) return false;
		Say("Обновляю лаунчер…", "");
		string fresh = self + ".new";
		DownloadTo(asset, fresh, "лаунчер");
		string cmd = Path.Combine(Path.GetTempPath(), "grimerka-launcher-update.cmd");
		File.WriteAllText(cmd, string.Join("\r\n", new string[] {
			"@echo off",
			"chcp 65001 >nul",
			"for /l %%i in (1,1,20) do (",
			"  move /y \"" + fresh + "\" \"" + self + "\" >nul 2>&1 && goto ok",
			"  ping -n 2 127.0.0.1 >nul",
			")",
			":ok",
			"start \"\" \"" + self + "\" --no-self-update",
			"del \"%~f0\"",
		}), new UTF8Encoding(false));
		ProcessStartInfo p = new ProcessStartInfo("cmd.exe", "/c \"" + cmd + "\"");
		p.WindowStyle = ProcessWindowStyle.Hidden;
		p.CreateNoWindow = true;
		Process.Start(p);
		Ui(delegate { Close(); });
		return true;
	}

	// ---------- запуск ----------
	bool IsGameRunning()
	{
		foreach (Process p in Process.GetProcessesByName("GOD OF GRIMERKA"))
		{
			try { if (string.Equals(p.MainModule.FileName, GameExe, StringComparison.OrdinalIgnoreCase)) return true; }
			catch { }
		}
		return false;
	}

	void Launch(string msg)
	{
		Say(msg, dir);
		Ui(delegate { bar.Style = ProgressBarStyle.Continuous; bar.Value = 100; });
		if (checkOnly)
		{
			Console.WriteLine("LAUNCHER ok: " + msg);
			Ui(delegate { Close(); });
			return;
		}
		ProcessStartInfo p = new ProcessStartInfo(GameExe, "-- \"--launcher=" + self + "\"");
		p.WorkingDirectory = dir;
		p.UseShellExecute = false;
		Process.Start(p);
		Thread.Sleep(1200);
		Ui(delegate { Close(); });
	}

	void Offline(string why, string d)
	{
		if (File.Exists(GameExe))
		{
			Say(why + " — запускаю установленную версию", d);
			Thread.Sleep(1500);
			Launch(why + " — запускаю установленную версию");
			return;
		}
		Fail(why, d);
	}

	void Fail(string why, string d)
	{
		if (checkOnly) Console.WriteLine("LAUNCHER fail: " + why + " — " + d);
		Ui(delegate
		{
			status.Text = why;
			detail.Text = d;
			bar.Style = ProgressBarStyle.Continuous;
			bar.Value = 0;
			retry.Visible = true;
			page.Visible = true;
		});
	}
}

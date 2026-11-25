// Установщик GOD OF GRIMERKA: своё рисованное окно в стиле игровых меню (чёрно-белый гранж, шрифт с засечками,
// рваные белые плашки, герои — рендер настоящих моделей из меню игры, heroes.png).
// Экраны: INTRO → INSTALL LOCATION → INSTALL OPTIONS → INSTALLATION → COMPLETE; отдельно — удаление (--uninstall).
// Установка настоящая: игра и лаунчер скачиваются из релиза godot-build на GitHub с проверкой SHA-256,
// в папке появляются игра, лаунчер (ярлыки ведут на него — так игра продолжает обновляться) и Uninstall.exe,
// запись об удалении пишется в «Приложения» Windows (HKCU, без прав администратора).
// Сохранения, настройки и музыка iPod лежат в %APPDATA%\Godot\app_userdata\GOD OF GRIMERKA и не трогаются,
// пока игрок сам не отметит их удаление при деинсталляции.
// Сборка: tools/setup/build.cmd (компилятор .NET Framework 4, есть в любой Windows 10/11).
// Ключи для проверки: --shots=<папка> (снимки всех экранов), --auto (установка без кликов), --dir=, --id=,
// --no-desktop, --no-start, --launch, --fake-free=<байт>, --cancel-at=<процент>, --log=<файл>,
// --uninstall, --wipe-data, --data-dir=<папка>.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Media;
using System.Net;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("GOD OF GRIMERKA — установка")]
[assembly: AssemblyProduct("GOD OF GRIMERKA")]
[assembly: AssemblyVersion("1.0.0.0")]

static class Program
{
	[System.Runtime.InteropServices.DllImport("user32.dll")]
	static extern bool SetProcessDPIAware();

	[STAThread]
	static void Main(string[] args)
	{
		try { SetProcessDPIAware(); } catch { }
		FastDownload.Setup();
		Application.EnableVisualStyles();
		Application.Run(new SetupForm(args));
	}
}

enum Scr { Intro, Location, Options, Installing, Complete, Failed, Uninstall, UninstallDone }

class Btn
{
	public string Id, Text;
	public RectangleF R;
	public bool Enabled = true, Check, Checked, Small;
	public float Hover;
}

class SetupForm : Form
{
	const string Api = "https://api.github.com/repos/jelos8vetoi/god-of-grimerka/releases/tags/godot-build";
	const string GameAsset = "GOD-OF-GRIMERKA-Godot.exe";
	const string LauncherAsset = "GOD-OF-GRIMERKA-Launcher.exe";
	const string GameFile = GamePackage.Exe;
	const string LauncherFile = "GOD OF GRIMERKA Launcher.exe";
	const string UninstFile = "Uninstall.exe";
	const string Marker = "grimerka-install.txt";
	const string UA = "god-of-grimerka-setup";
	const float W = 1600f, H = 900f;

	static readonly Color White = Color.FromArgb(242, 244, 247), Silver = Color.FromArgb(184, 188, 196), Grey = Color.FromArgb(117, 122, 130), Ink = Color.FromArgb(8, 8, 9);

	// параметры запуска
	string id = "GodOfGrimerka";
	string name = "GOD OF GRIMERKA";
	string shotsDir, logFile, dataDirOverride;
	bool auto, uninstallMode, wipeData;
	long fakeFree = -1;
	int cancelAt = -1;

	// выбор игрока
	string installDir;
	bool optDesktop = true, optStart = true, optLaunch = true, optPrev = true, sound = true;
	string prevDir = "", prevStamp = "";
	long locationFree;
	float nextDiskCheck;

	// состояние
	Scr scr = Scr.Intro, next = Scr.Intro;
	float t, scrT, fade = 1f;      // fade: 1 — экран виден; уход — к 0, затем смена
	bool leaving;
	readonly List<Btn> btns = new List<Btn>();
	int focus;
	PointF mouse = new PointF(-1, -1);
	readonly Stopwatch clock = Stopwatch.StartNew();
	double last;
	string build = "";
	long needBytes = 230L * 1048576L;

	// установка (пишет рабочий поток)
	volatile string phase = "";
	volatile string failText = "";
	volatile bool cancel, working;
	long done, total;
	double speed;
	int filesDone, filesTotal = 3;
	float shownPct;
	string resultNote = "";

	// графика
	Bitmap back, heroes, portrait, grain, grainLayer, specks;
	Size grainSize;
	Bitmap scaledBack, scaledHeroes, scaledPortrait;
	float artScale;
	string serifName, techName;
	readonly Dictionary<float, Font> serifFonts = new Dictionary<float, Font>();
	readonly Dictionary<float, Font> techFonts = new Dictionary<float, Font>();
	readonly Dictionary<string, SoundPlayer> sfx = new Dictionary<string, SoundPlayer>();
	readonly Random rnd = new Random(7);

	public SetupForm(string[] args)
	{
		installDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "GOD OF GRIMERKA");
		bool dirGiven = false;
		foreach (string a in args)
		{
			if (a.StartsWith("--shots=")) shotsDir = a.Substring(8);
			else if (a == "--auto") { auto = true; optLaunch = false; }
			else if (a.StartsWith("--dir=")) { installDir = a.Substring(6); dirGiven = true; }
			else if (a.StartsWith("--id=")) { id = a.Substring(5); name = "GOD OF GRIMERKA (" + id + ")"; }
			else if (a == "--no-desktop") optDesktop = false;
			else if (a == "--no-start") optStart = false;
			else if (a == "--launch") optLaunch = true;
			else if (a.StartsWith("--fake-free=")) fakeFree = long.Parse(a.Substring(12));
			else if (a.StartsWith("--cancel-at=")) cancelAt = int.Parse(a.Substring(12));
			else if (a.StartsWith("--log=")) logFile = a.Substring(6);
			else if (a == "--uninstall") uninstallMode = true;
			else if (a == "--wipe-data") wipeData = true;
			else if (a.StartsWith("--data-dir=")) dataDirOverride = a.Substring(11);
		}
		ReadPrevious();
		if (!dirGiven && prevDir != "") installDir = prevDir;
		if (uninstallMode && !dirGiven) installDir = prevDir != "" ? prevDir : Path.GetDirectoryName(Application.ExecutablePath);

		Text = uninstallMode ? "GOD OF GRIMERKA — удаление" : "GOD OF GRIMERKA — установка";
		ClientSize = new Size(1280, 720);
		MinimumSize = new Size(820, 500);
		StartPosition = FormStartPosition.CenterScreen;
		BackColor = Color.Black;
		DoubleBuffered = true;
		SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
		KeyPreview = true;
		try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

		serifName = Pick(new string[] { "Bodoni MT Black", "Bodoni MT", "Playfair Display", "Georgia", "Times New Roman" });
		techName = Pick(new string[] { "Bahnschrift", "Segoe UI", "Arial" });
		BuildArt();
		BuildSounds();
		Disposed += delegate
		{
			foreach (Font f in serifFonts.Values) f.Dispose();
			foreach (Font f in techFonts.Values) f.Dispose();
			foreach (SoundPlayer player in sfx.Values) player.Dispose();
			back.Dispose();
			if (heroes != null) heroes.Dispose();
			if (portrait != null) portrait.Dispose();
			if (grainLayer != null) grainLayer.Dispose();
			grain.Dispose();
			specks.Dispose();
			DisposeScaledArt();
		};
		scr = uninstallMode ? Scr.Uninstall : Scr.Intro;
		next = scr;
		Layout2();

		if (shotsDir != null) { Shown += delegate { Shots(); Close(); }; return; }

		System.Windows.Forms.Timer tm = new System.Windows.Forms.Timer();
		tm.Interval = 16;
		tm.Tick += delegate
		{
			Step();
			if (WindowState != FormWindowState.Minimized)
				Invalidate();
		};
		Disposed += delegate { tm.Dispose(); };
		tm.Start();
		MouseMove += delegate(object s, MouseEventArgs e) { mouse = ToStage(e.Location); };
		MouseLeave += delegate { mouse = new PointF(-1, -1); };
		MouseDown += delegate(object s, MouseEventArgs e) { if (e.Button == MouseButtons.Left) ClickAt(ToStage(e.Location)); };
		KeyDown += OnKey;
		FormClosing += delegate(object s, FormClosingEventArgs e)
		{
			if (working && !auto) { cancel = true; e.Cancel = true; }   // сначала безопасно прервать загрузку
		};
		if (!uninstallMode) { Thread th = new Thread(FetchBuild); th.IsBackground = true; th.Start(); }
		if (auto)
		{
			Shown += delegate
			{
				if (uninstallMode) { DoUninstall(); Log("uninstall done: " + resultNote); Close(); }
				else Go(Scr.Installing);
			};
		}
	}

	string Pick(string[] names)
	{
		using (InstalledFontCollection fc = new InstalledFontCollection())
			foreach (string n in names)
				foreach (FontFamily f in fc.Families)
					if (string.Equals(f.Name, n, StringComparison.OrdinalIgnoreCase)) return f.Name;
		return FontFamily.GenericSerif.Name;
	}

	void Log(string s)
	{
		if (logFile != null) File.AppendAllText(logFile, s + "\r\n", Encoding.UTF8);
	}

	// ---------------- картинки ----------------
	void BuildArt()
	{
		using (Stream st = Assembly.GetExecutingAssembly().GetManifestResourceStream("heroes.png"))
			if (st != null)
				using (Bitmap source = new Bitmap(st))
				{
					heroes = new Bitmap(1000, 900, PixelFormat.Format32bppPArgb);
					using (Graphics g = Graphics.FromImage(heroes))
					{
						g.InterpolationMode = InterpolationMode.HighQualityBilinear;
						g.DrawImage(source, 0, 0, heroes.Width, heroes.Height);
					}
				}
		// фон: мазки сухой кистью, кольца, силуэт города, мокрый пол
		back = new Bitmap((int)W, (int)H, PixelFormat.Format32bppPArgb);
		using (Graphics g = Graphics.FromImage(back))
		{
			g.SmoothingMode = SmoothingMode.AntiAlias;
			g.Clear(Color.FromArgb(10, 10, 12));
			Random r = new Random(11);
			for (int i = 0; i < 260; i++)
			{
				float y = (float)r.NextDouble() * 1500f - 300f, x = (float)r.NextDouble() * 1400f - 400f, len = 200f + (float)r.NextDouble() * 900f;
				using (Pen p = new Pen(Color.FromArgb(4 + r.Next(22), 255, 255, 255), 1f + (float)r.NextDouble() * 10f))
					g.DrawLine(p, x, y, x + len, y - len * 0.36f);
			}
			using (Pen p = new Pen(Color.FromArgb(120, 255, 255, 255), 5f)) g.DrawEllipse(p, 1130 - 410, 470 - 410, 820, 820);
			using (Pen p = new Pen(Color.FromArgb(70, 255, 255, 255), 2f)) g.DrawEllipse(p, 1180 - 290, 430 - 290, 580, 580);
			using (Pen p = new Pen(Color.FromArgb(40, 255, 255, 255), 1.5f)) g.DrawEllipse(p, 560 - 360, 560 - 360, 720, 720);
			float hor = 670f;
			using (LinearGradientBrush glow = new LinearGradientBrush(new RectangleF(0, 250, W, hor - 250), Color.FromArgb(0, 255, 255, 255), Color.FromArgb(46, 255, 255, 255), 90f))
				g.FillRectangle(glow, 420, 250, W - 420, hor - 250);
			for (float x = 380; x < W; )
			{
				float w = 16f + r.Next(34), h = 40f + r.Next(150) + (r.Next(8) == 0 ? 120f : 0f);
				h *= Math.Min(1f, (x - 330f) / 500f);
				using (SolidBrush b = new SolidBrush(Color.FromArgb(9, 9, 11))) g.FillRectangle(b, x, hor - h, w, h);
				for (int k = 0; k < 6; k++)
					if (r.Next(3) == 0)
						using (SolidBrush b = new SolidBrush(Color.FromArgb(60, 255, 255, 255))) g.FillRectangle(b, x + 3 + r.Next((int)w - 5), hor - h + 6 + r.Next((int)Math.Max(1, h - 10)), 2, 3);
				x += w + r.Next(5);
			}
			using (SolidBrush b = new SolidBrush(Color.FromArgb(9, 9, 11))) g.FillRectangle(b, 0, hor, W, H - hor);
			for (int i = 0; i < 90; i++)
				using (Pen p = new Pen(Color.FromArgb(6 + r.Next(14), 255, 255, 255), 1f))
				{
					float y = hor + 6 + r.Next((int)(H - hor - 8)), x = r.Next((int)W);
					g.DrawLine(p, x, y, x + 60 + r.Next(260), y);
				}
			for (int i = 0; i < 900; i++)
				using (SolidBrush b = new SolidBrush(Color.FromArgb(20 + r.Next(90), 255, 255, 255)))
				{
					float s = 0.6f + (float)r.NextDouble() * 2.4f;
					g.FillEllipse(b, r.Next((int)W), r.Next((int)H), s, s);
				}
		}
		grain = new Bitmap(256, 256, PixelFormat.Format32bppPArgb);
		specks = new Bitmap(256, 256, PixelFormat.Format32bppArgb);
		Random q = new Random(5);
		for (int y = 0; y < 256; y++)
			for (int x = 0; x < 256; x++)
			{
				int v = q.Next(256);
				grain.SetPixel(x, y, Color.FromArgb(q.Next(26), v, v, v));
				specks.SetPixel(x, y, q.Next(100) < 5 ? Color.FromArgb(120 + q.Next(120), 8, 8, 9) : Color.Transparent);
			}
		using (Graphics g = Graphics.FromImage(specks))
			for (int i = 0; i < 26; i++)
				using (SolidBrush b = new SolidBrush(Color.FromArgb(200, 8, 8, 9)))
					g.FillEllipse(b, q.Next(256), q.Next(256), 2 + q.Next(9), 1 + q.Next(4));
		if (heroes != null)
		{
			// Crop the pre-tinted portrait to the area visible during parallax.
			portrait = new Bitmap(1282, 908, PixelFormat.Format32bppPArgb);
			using (Graphics g = Graphics.FromImage(portrait))
			{
				g.InterpolationMode = InterpolationMode.HighQualityBilinear;
				Hero(g, heroes, 11, -334, 2300, 2070, 0.22f, 0.5f);
			}
		}
	}

	// ---------------- звук: синтезируется при запуске, файлов нет ----------------
	void BuildSounds()
	{
		sfx["hover"] = Tone(0.03, 1500, 0.10, 0);
		sfx["click"] = Tone(0.07, 420, 0.30, 0);
		sfx["page"] = Tone(0.20, 220, 0.24, 900);
		sfx["done"] = Tone(0.60, 330, 0.30, 660);
		sfx["fail"] = Tone(0.30, 160, 0.30, -60);
	}

	SoundPlayer Tone(double sec, double f0, double amp, double sweep)
	{
		int rate = 22050, n = (int)(sec * rate);
		MemoryStream ms = new MemoryStream();
		BinaryWriter w = new BinaryWriter(ms);
		w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write(36 + n * 2); w.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
		w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(rate); w.Write(rate * 2); w.Write((short)2); w.Write((short)16);
		w.Write(Encoding.ASCII.GetBytes("data")); w.Write(n * 2);
		double ph = 0;
		Random r = new Random(3);
		for (int i = 0; i < n; i++)
		{
			double tt = (double)i / rate, k = tt / sec;
			ph += 2 * Math.PI * (f0 + sweep * k) / rate;
			double env = (1 - Math.Exp(-tt * 900)) * Math.Exp(-tt * (3.5 / sec));
			double v = (Math.Sin(ph) + 0.35 * Math.Sin(ph * 2.01) + (r.NextDouble() - 0.5) * 0.25 * Math.Exp(-tt * 60)) * env * amp;
			w.Write((short)(Math.Max(-1, Math.Min(1, v)) * 32000));
		}
		ms.Position = 0;
		SoundPlayer p = new SoundPlayer(ms);
		try { p.Load(); } catch { }
		return p;
	}

	void Play(string k)
	{
		if (!sound || auto || shotsDir != null) return;
		try { sfx[k].Play(); } catch { }
	}

	// ---------------- прежняя установка ----------------
	string UninstKey { get { return @"Software\Microsoft\Windows\CurrentVersion\Uninstall\" + id; } }

	void ReadPrevious()
	{
		try
		{
			using (RegistryKey k = Registry.CurrentUser.OpenSubKey(UninstKey))
				if (k != null)
				{
					prevDir = Convert.ToString(k.GetValue("InstallLocation", ""));
					prevStamp = Convert.ToString(k.GetValue("GrimerkaStamp", ""));
					if (prevDir != "" && !Directory.Exists(prevDir)) prevDir = "";
				}
		}
		catch { }
	}

	string DataDir
	{
		get { return dataDirOverride ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Godot", "app_userdata", "GOD OF GRIMERKA"); }
	}

	long FreeBytes(string dir)
	{
		if (fakeFree >= 0) return fakeFree;
		try { return new DriveInfo(Path.GetPathRoot(Path.GetFullPath(dir))).AvailableFreeSpace; } catch { return -1; }
	}

	bool DirOk(out string why)
	{
		return DirOk(FreeBytes(installDir), out why);
	}

	bool DirOk(long free, out string why)
	{
		why = "";
		if (free < 0) { why = "Диск недоступен — выбери другую папку."; return false; }
		if (free < needBytes) { why = "Не хватает места: нужно " + Mb(needBytes) + ", свободно " + Mb(free) + "."; return false; }
		return true;
	}

	static string Mb(long b) { return b >= 1073741824L ? string.Format("{0:0.0} ГБ", b / 1073741824.0) : string.Format("{0:0} МБ", b / 1048576.0); }

	// ---------------- экраны и кнопки ----------------
	Btn Add(string bid, string text, float x, float y, float w, float h)
	{
		Btn b = new Btn(); b.Id = bid; b.Text = text; b.R = new RectangleF(x, y, w, h);
		btns.Add(b);
		return b;
	}

	Btn AddCheck(string bid, string text, float y, bool on)
	{
		Btn b = Add(bid, text, 110, y, 620, 54); b.Check = true; b.Checked = on;
		return b;
	}

	void Layout2()
	{
		btns.Clear();
		focus = 0;
		switch (scr)
		{
			case Scr.Intro:
				Add("install", prevDir != "" ? "UPDATE GAME" : "INSTALL GAME", 96, 560, 640, 92);
				Add("exit", "EXIT", 96, 668, 300, 60);
				break;
			case Scr.Location:
				locationFree = FreeBytes(installDir);
				nextDiskCheck = t + 1f;
				Add("change", "CHANGE LOCATION", 110, 470, 420, 60);
				Add("next", "NEXT", 110, 700, 300, 76);
				Add("back", "BACK", 430, 708, 220, 60);
				break;
			case Scr.Options:
				AddCheck("o_desktop", "Ярлык на рабочем столе", 300, optDesktop);
				AddCheck("o_start", "Ярлык в меню «Пуск»", 362, optStart);
				AddCheck("o_launch", "Запустить игру после установки", 424, optLaunch);
				AddCheck("o_prev", "Не качать заново, если версия та же", 486, optPrev);
				Add("go", "INSTALL", 110, 700, 340, 76);
				Add("back", "BACK", 470, 708, 220, 60);
				break;
			case Scr.Installing:
				Add("cancel", "CANCEL", 110, 760, 260, 56);
				break;
			case Scr.Complete:
				Add("launch", "LAUNCH GAME", 96, 500, 640, 92);
				Add("folder", "OPEN INSTALL FOLDER", 96, 608, 640, 60);
				Add("exit", "EXIT", 96, 680, 300, 60);
				break;
			case Scr.Failed:
				Add("retry", "TRY AGAIN", 96, 560, 420, 80);
				Add("exit", "EXIT", 96, 656, 300, 60);
				break;
			case Scr.Uninstall:
				AddCheck("u_data", "Удалить и сохранения с настройками", 430, wipeData);
				Add("uninstall", "UNINSTALL", 110, 560, 420, 80);
				Add("exit", "KEEP THE GAME", 110, 656, 420, 60);
				break;
			case Scr.UninstallDone:
				Add("exit", "EXIT", 96, 600, 300, 76);
				break;
		}
		Btn snd = Add("sound", sound ? "SOUND: ON" : "SOUND: OFF", 1380, 30, 190, 34);
		snd.Small = true;
	}

	void Go(Scr s)
	{
		if (leaving) return;
		next = s;
		leaving = true;
		Play("page");
	}

	void EnterScreen(Scr s)
	{
		scr = s;
		scrT = 0f;
		leaving = false;
		Layout2();
		if (s == Scr.Installing) StartInstall();
		if (s == Scr.Complete) Play("done");
		if (s == Scr.Failed) Play("fail");
	}

	void Press(Btn b)
	{
		if (!b.Enabled || leaving) return;
		Play("click");
		switch (b.Id)
		{
			case "sound": sound = !sound; b.Text = sound ? "SOUND: ON" : "SOUND: OFF"; Play("click"); break;
			case "exit": Close(); break;
			case "install": Go(Scr.Location); break;
			case "back": Go(scr == Scr.Options ? Scr.Location : Scr.Intro); break;
			case "change":
				using (FolderBrowserDialog d = new FolderBrowserDialog())
				{
					d.Description = "Куда поставить GOD OF GRIMERKA";
					d.SelectedPath = Directory.Exists(installDir) ? installDir : Path.GetDirectoryName(installDir);
					if (d.ShowDialog(this) == DialogResult.OK)
					{
						installDir = d.SelectedPath.TrimEnd('\\').EndsWith("GOD OF GRIMERKA", StringComparison.OrdinalIgnoreCase) ? d.SelectedPath : Path.Combine(d.SelectedPath, "GOD OF GRIMERKA");
						nextDiskCheck = t;
					}
				}
				break;
			case "next": { string why; if (DirOk(out why)) Go(Scr.Options); break; }
			case "o_desktop": optDesktop = b.Checked = !b.Checked; break;
			case "o_start": optStart = b.Checked = !b.Checked; break;
			case "o_launch": optLaunch = b.Checked = !b.Checked; break;
			case "o_prev": optPrev = b.Checked = !b.Checked; break;
			case "u_data": wipeData = b.Checked = !b.Checked; break;
			case "go": Go(Scr.Installing); break;
			case "cancel": cancel = true; phase = "ОТМЕНЯЮ…"; break;
			case "retry": Go(Scr.Installing); break;
			case "launch": LaunchGame(); Close(); break;
			case "folder": try { Process.Start("explorer.exe", "\"" + installDir + "\""); } catch { } break;
			case "uninstall": DoUninstall(); Go(Scr.UninstallDone); break;
		}
	}

	void OnKey(object s, KeyEventArgs e)
	{
		List<Btn> main = btns.FindAll(delegate(Btn b) { return !b.Small; });
		if (main.Count == 0) return;
		if (e.KeyCode == Keys.Down || e.KeyCode == Keys.S || e.KeyCode == Keys.Tab) { focus = (focus + 1) % main.Count; Play("hover"); }
		else if (e.KeyCode == Keys.Up || e.KeyCode == Keys.W) { focus = (focus + main.Count - 1) % main.Count; Play("hover"); }
		else if (e.KeyCode == Keys.Enter || e.KeyCode == Keys.Space) Press(main[Math.Min(focus, main.Count - 1)]);
		else if (e.KeyCode == Keys.Escape)
		{
			if (scr == Scr.Location || scr == Scr.Options) Go(scr == Scr.Options ? Scr.Location : Scr.Intro);
			else if (scr == Scr.Installing) { cancel = true; phase = "ОТМЕНЯЮ…"; }
			else Close();
		}
		e.Handled = true;
	}

	void ClickAt(PointF p)
	{
		foreach (Btn b in btns)
			if (b.R.Contains(p)) { Press(b); return; }
	}

	// ---------------- время ----------------
	void Step()
	{
		double now = clock.Elapsed.TotalSeconds;
		float dt = (float)Math.Min(0.05, now - last);
		last = now;
		t += dt;
		scrT += dt;
		if (leaving) { fade -= dt / 0.14f; if (fade <= 0f) { fade = 0f; EnterScreen(next); } }
		else fade = Math.Min(1f, fade + dt / 0.2f);
		List<Btn> main = btns.FindAll(delegate(Btn b) { return !b.Small; });
		for (int i = 0; i < btns.Count; i++)
		{
			Btn b = btns[i];
			bool over = b.R.Contains(mouse);
			if (over && !b.Small && main.IndexOf(b) != focus) { focus = main.IndexOf(b); Play("hover"); }
			bool hot = over || (!b.Small && main.IndexOf(b) == focus);
			float target = hot ? 1f : 0f;
			if (b.Hover != target)
			{
				b.Hover += (target - b.Hover) * Math.Min(1f, dt * 14f);
				if (Math.Abs(b.Hover - target) < 0.005f) b.Hover = target;
			}
		}
		if (scr == Scr.Location)
		{
			if (t >= nextDiskCheck)
			{
			locationFree = FreeBytes(installDir);
				nextDiskCheck = t + 1f;
			}
			string why;
			Btn nx = btns.Find(delegate(Btn b) { return b.Id == "next"; });
			if (nx != null) nx.Enabled = DirOk(locationFree, out why);
		}
		if (scr == Scr.Installing)
		{
			float pct = total > 0 ? (float)(Interlocked.Read(ref done) * 100.0 / total) : 0f;
			shownPct += (pct - shownPct) * Math.Min(1f, dt * 8f);
			if (cancelAt >= 0 && pct >= cancelAt) cancel = true;
			if (!working && scrT > 0.3f)
			{
				if (failText == "") { if (auto) { Log("install ok: " + resultNote); Close(); } else Go(Scr.Complete); }
				else if (auto) { Log("install fail: " + failText); Close(); }
				else Go(Scr.Failed);
			}
		}
	}

	// ---------------- рисование ----------------
	PointF ToStage(Point p)
	{
		float k = Math.Min(ClientSize.Width / W, ClientSize.Height / H);
		return new PointF((p.X - (ClientSize.Width - W * k) / 2f) / k, (p.Y - (ClientSize.Height - H * k) / 2f) / k);
	}

	protected override void OnPaint(PaintEventArgs e)
	{
		Draw(e.Graphics, ClientSize);
	}

	Font F(bool serif, float size)
	{
		Dictionary<float, Font> fonts = serif ? serifFonts : techFonts;
		Font font;
		if (!fonts.TryGetValue(size, out font))
		{
			font = new Font(serif ? serifName : techName, size, serif ? FontStyle.Bold : FontStyle.Regular, GraphicsUnit.Pixel);
			fonts.Add(size, font);
		}
		return font;
	}

	void Txt(Graphics g, string s, bool serif, float size, Color c, float x, float y, float alpha)
	{
		if (alpha <= 0.01f) return;
		Font f = F(serif, size);
		using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(255 * Math.Min(1f, alpha)), c)))
			g.DrawString(s, f, b, x, y, StringFormat.GenericTypographic);
	}

	void TxtBox(Graphics g, string s, bool serif, float size, Color c, RectangleF r, StringAlignment al, float alpha)
	{
		if (alpha <= 0.01f) return;
		Font f = F(serif, size);
		using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(255 * Math.Min(1f, alpha)), c)))
		using (StringFormat sf = new StringFormat(StringFormat.GenericTypographic))
		{
			sf.Alignment = al;
			sf.LineAlignment = StringAlignment.Center;
			sf.Trimming = StringTrimming.EllipsisPath;
			sf.FormatFlags |= StringFormatFlags.NoWrap;
			g.DrawString(s, f, b, r, sf);
		}
	}

	PointF[] Torn(float x, float y, float w, float h, int seed)
	{
		Random r = new Random(seed);
		List<PointF> p = new List<PointF>();
		for (float a = 0; a < w; a += 9 + r.Next(18)) p.Add(new PointF(x + a, y + r.Next(-4, 4)));
		for (float a = 0; a < h; a += 7 + r.Next(9)) p.Add(new PointF(x + w + r.Next(-10, 18) + 22f * (1f - Math.Abs(a / h - 0.5f) * 2f), y + a));
		for (float a = w; a > 0; a -= 9 + r.Next(18)) p.Add(new PointF(x + a, y + h + r.Next(-4, 5)));
		for (float a = h; a > 0; a -= 8 + r.Next(9)) p.Add(new PointF(x + r.Next(-14, 8), y + a));
		return p.ToArray();
	}

	void Band(Graphics g, float x, float y, float w, float h, int seed, float alpha)
	{
		if (w < 4 || alpha <= 0.01f) return;
		PointF[] p = Torn(x, y, w, h, seed);
		using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(255 * Math.Min(1f, alpha)), White))) g.FillPolygon(b, p);
		using (TextureBrush tb = new TextureBrush(specks)) g.FillPolygon(tb, p);
	}

	void Hero(Graphics g, Bitmap image, float x, float y, float w, float h, float alpha, float dim)
	{
		if (image == null || alpha <= 0.01f) return;
		Rectangle dest = new Rectangle((int)x, (int)y, (int)w, (int)h);
		if (alpha == 1f && dim == 1f)
		{
			g.DrawImage(image, dest);
			return;
		}
		ColorMatrix m = new ColorMatrix();
		m.Matrix00 = m.Matrix11 = m.Matrix22 = dim;
		m.Matrix33 = alpha;
		using (ImageAttributes ia = new ImageAttributes())
		{
			ia.SetColorMatrix(m);
			g.DrawImage(image, dest, 0, 0, image.Width, image.Height, GraphicsUnit.Pixel, ia);
		}
	}

	static float Ease(float x) { x = Math.Max(0f, Math.Min(1f, x)); return 1f - (1f - x) * (1f - x) * (1f - x); }

	void DisposeScaledArt()
	{
		if (scaledBack != null) scaledBack.Dispose();
		if (scaledHeroes != null) scaledHeroes.Dispose();
		if (scaledPortrait != null) scaledPortrait.Dispose();
	}

	static Bitmap ScaleArt(Bitmap image, float scale)
	{
		if (image == null) return null;
		Bitmap scaled = new Bitmap(Math.Max(1, (int)(image.Width * scale)), Math.Max(1, (int)(image.Height * scale)), PixelFormat.Format32bppPArgb);
		using (Graphics g = Graphics.FromImage(scaled))
		{
			g.InterpolationMode = InterpolationMode.HighQualityBilinear;
			g.DrawImage(image, 0, 0, scaled.Width, scaled.Height);
		}
		return scaled;
	}

	void DrawGrain(Graphics g, Size client)
	{
		if (grainLayer == null || grainSize != client)
		{
			if (grainLayer != null) grainLayer.Dispose();
			grainLayer = new Bitmap(client.Width + 255, client.Height + 255, PixelFormat.Format32bppPArgb);
			grainSize = client;
			using (Graphics layer = Graphics.FromImage(grainLayer))
			using (TextureBrush brush = new TextureBrush(grain))
				layer.FillRectangle(brush, 0, 0, grainLayer.Width, grainLayer.Height);
		}
		GraphicsState state = g.Save();
		g.ResetTransform();
		g.DrawImageUnscaled(grainLayer, -rnd.Next(256), -rnd.Next(256));
		g.Restore(state);
	}

	// появление элемента: задержка d секунд от входа на экран; возвращает 0..1
	float In(float d) { return Ease((scrT - d) / 0.32f) * fade; }

	void Draw(Graphics g, Size client)
	{
		g.Clear(Color.Black);
		float k = Math.Min(client.Width / W, client.Height / H);
		if (k <= 0f) return;
		int left = (int)((client.Width - W * k) / 2f), top = (int)((client.Height - H * k) / 2f);
		if (scaledBack == null || artScale != k)
		{
			DisposeScaledArt();
			scaledBack = ScaleArt(back, k);
			scaledHeroes = ScaleArt(heroes, k);
			scaledPortrait = ScaleArt(portrait, k);
			artScale = k;
		}
		g.SetClip(new Rectangle(left, top, scaledBack.Width, scaledBack.Height));
		g.DrawImageUnscaled(scaledBack, left, top);
		float px = mouse.X < 0 ? 0f : Math.Max(-0.5f, Math.Min(0.5f, mouse.X / W - 0.5f));
		float py = mouse.Y < 0 ? 0f : Math.Max(-0.5f, Math.Min(0.5f, mouse.Y / H - 0.5f));
		bool busy = scr == Scr.Installing;
		float heroA = (scr == Scr.Uninstall || scr == Scr.UninstallDone ? 0.45f : 1f) * Ease(t / 0.9f);
		if (scaledPortrait != null)
			Hero(g, scaledPortrait, left + (319 + px * 22) * k, top + (-4 + py * 8) * k, scaledPortrait.Width, scaledPortrait.Height, heroA, 1f);
		if (scaledHeroes != null)
			Hero(g, scaledHeroes, left + (615 - px * 14 + (1f - Ease(t / 0.9f)) * 60f) * k, top + (10 - py * 6 + (float)Math.Sin(t * 0.7) * 1.5f) * k, scaledHeroes.Width, scaledHeroes.Height, heroA, busy ? 0.55f + 0.45f * shownPct / 100f : 1f);

		g.TranslateTransform(left, top);
		g.ScaleTransform(k, k);
		g.SmoothingMode = SmoothingMode.AntiAlias;
		g.TextRenderingHint = TextRenderingHint.AntiAlias;
		g.InterpolationMode = InterpolationMode.Bilinear;
		g.SetClip(new RectangleF(0, 0, W, H));

		switch (scr)
		{
			case Scr.Intro: DrawIntro(g); break;
			case Scr.Location: DrawLocation(g); break;
			case Scr.Options: DrawOptions(g); break;
			case Scr.Installing: DrawInstalling(g); break;
			case Scr.Complete: DrawComplete(g); break;
			case Scr.Failed: DrawFailed(g); break;
			case Scr.Uninstall: DrawUninstall(g); break;
			case Scr.UninstallDone: DrawHeader(g, "09", "UNINSTALLED"); Txt(g, "ИГРА УДАЛЕНА", true, 84, White, 96, 250, In(0.05f)); Txt(g, resultNote, false, 22, Silver, 100, 400, In(0.15f)); Txt(g, "SEE YOU IN THE CLOUD.", true, 26, Grey, 100, 470, In(0.25f)); break;
		}
		DrawButtons(g);
		// нижние подписи
		Txt(g, "ENTER — выбрать   ·   ↑ ↓ — перейти   ·   ESC — назад", false, 15, Grey, 48, 862, fade);
		TxtBox(g, "BUILD " + (build != "" ? build : "—") + "   ·   GOD OF GRIMERKA", false, 14, Grey, new RectangleF(1100, 858, 470, 24), StringAlignment.Far, 1f);
		DrawGrain(g, client);
		float gl = (float)Math.Sin(t * 1.7) * (float)Math.Sin(t * 0.37);
		if (gl > 0.93f && shotsDir == null)
			using (SolidBrush b = new SolidBrush(Color.FromArgb(26, 255, 255, 255)))
				g.FillRectangle(b, 0, 120 + rnd.Next(600), W, 3 + rnd.Next(10));
		g.ResetTransform();
		g.ResetClip();
	}

	void DrawHeader(Graphics g, string num, string title)
	{
		float a = In(0f);
		Txt(g, num, true, 34, White, 32, 30, a);
		Txt(g, "/ GOD OF GRIMERKA\n/ " + title, false, 14, Silver, 90, 34, a);
		using (Pen p = new Pen(Color.FromArgb((int)(120 * a), 255, 255, 255), 1f)) g.DrawLine(p, 32, 84, 32 + 420 * a, 84);
	}

	void Logo(Graphics g, float x, float y, float s, float a)
	{
		GraphicsState st = g.Save();
		g.TranslateTransform(x, y);
		g.RotateTransform(-3.5f);
		Txt(g, "G", true, 330 * s, White, 0, -78 * s, a);
		Txt(g, "OD OF", true, 90 * s, White, 232 * s + (1f - a) * 40f, 22 * s, a);
		Txt(g, "RIMERKA", true, 124 * s, White, 212 * s + (1f - a) * 70f, 100 * s, a);
		g.Restore(st);
	}

	void DrawIntro(Graphics g)
	{
		DrawHeader(g, "01", "INSTALLER");
		Logo(g, 70, 110, 1f, In(0.1f));
		Txt(g, "AN UNDERGROUND ACTION RPG", true, 21, Silver, 300, 382, In(0.35f));
		Txt(g, "DEVELOPED IN THE CLOUD", false, 15, Grey, 302, 414, In(0.42f));
		Txt(g, prevDir != "" ? "УЖЕ УСТАНОВЛЕНА: " + prevDir : "ИГРА СТАВИТСЯ ИЗ ОБЛАКА — НУЖЕН ИНТЕРНЕТ, " + Mb(needBytes), false, 15, Grey, 100, 520, In(0.5f));
	}

	void DrawLocation(Graphics g)
	{
		DrawHeader(g, "02", "INSTALL LOCATION");
		Txt(g, "КУДА СТАВИМ", true, 84, White, 104, 130, In(0.05f));
		Band(g, 96, 300, 640 * In(0.15f), 74, 21, In(0.15f));
		TxtBox(g, installDir, false, 26, Ink, new RectangleF(116, 300, 600, 74), StringAlignment.Near, In(0.2f));
		long free = locationFree;
		string why;
		bool okDir = DirOk(free, out why);
		Txt(g, "НУЖНО: " + Mb(needBytes) + "    СВОБОДНО: " + (free < 0 ? "—" : Mb(free)), true, 26, White, 110, 400, In(0.25f));
		Txt(g, okDir ? "Права администратора не нужны.\nСохранения лежат отдельно и при обновлении не трогаются." : why, false, 18, okDir ? Silver : White, 110, 560, In(0.3f));
		if (!okDir) Band(g, 96, 600, 14, 14, 3, In(0.3f));
	}

	void DrawOptions(Graphics g)
	{
		DrawHeader(g, "03", "INSTALL OPTIONS");
		Txt(g, "КАК СТАВИМ", true, 84, White, 104, 130, In(0.05f));
		Txt(g, prevDir != "" ? "Найдена установка в " + prevDir + " — она будет обновлена." : "Предыдущей установки не найдено.", false, 18, Silver, 110, 580, In(0.3f));
	}

	void DrawInstalling(Graphics g)
	{
		DrawHeader(g, "04", "INSTALLATION");
		float a = In(0.05f);
		// диагональная полоса прогресса через весь экран
		GraphicsState st = g.Save();
		g.TranslateTransform(60, 560);
		g.RotateTransform(-7f);
		using (Pen p = new Pen(Color.FromArgb((int)(90 * a), 255, 255, 255), 2f)) g.DrawLine(p, 0, 34, 700, 34);
		Band(g, 0, 0, 700 * shownPct / 100f, 68, 31, a);
		g.Restore(st);
		Txt(g, ((int)shownPct).ToString(), true, 300, White, 96, 100, a);
		Font f = F(true, 300);
		{
			float w = g.MeasureString(((int)shownPct).ToString(), f, 2000, StringFormat.GenericTypographic).Width;
			Txt(g, "%", true, 120, Silver, 110 + w, 270, a);
		}
		Txt(g, phase, true, 30, White, 110, 640, a);
		long d = Interlocked.Read(ref done);
		string line = total > 0 ? Mb(d) + " из " + Mb(total) + "   ·   осталось " + Mb(Math.Max(0, total - d)) + (speed > 0.05 ? string.Format("   ·   {0:0.0} МБ/с", speed) : "") : "";
		Txt(g, line, false, 20, Silver, 112, 688, a);
		Txt(g, "ФАЙЛЫ: " + filesDone + " / " + filesTotal, false, 16, Grey, 112, 720, a);
		// бегущие технические штрихи
		for (int i = 0; i < 7; i++)
			using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(60 * a), 255, 255, 255)))
				g.FillRectangle(b, 112 + ((t * 140f + i * 190f) % 1100f), 748, 30 + i * 6, 2);
	}

	void DrawComplete(Graphics g)
	{
		DrawHeader(g, "05", "COMPLETE");
		Band(g, 0, 150, 680 * In(0.05f), 150, 41, In(0.05f));
		Txt(g, "INSTALLATION", true, 66, Ink, 96, 156, In(0.12f));
		Txt(g, "COMPLETE", true, 66, Ink, 96, 222, In(0.18f));
		Logo(g, 96, 330, 0.34f, In(0.3f));
		Font nf = F(false, 16);
		using (SolidBrush nb = new SolidBrush(Color.FromArgb((int)(255 * In(0.4f)), Silver)))
			g.DrawString(resultNote, nf, nb, new RectangleF(100, 440, 600, 56));
		TxtBox(g, "SEE YOU IN THE CLOUD.", true, 22, Grey, new RectangleF(660, 800, 440, 30), StringAlignment.Near, In(0.6f));
	}

	void DrawFailed(Graphics g)
	{
		DrawHeader(g, "!!", "ERROR");
		Txt(g, "НЕ ВЫШЛО", true, 100, White, 96, 170, In(0.05f));
		Font f = F(false, 22);
		using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(255 * In(0.15f)), Silver)))
			g.DrawString(failText, f, b, new RectangleF(100, 340, 620, 200));
	}

	void DrawUninstall(Graphics g)
	{
		DrawHeader(g, "09", "UNINSTALL");
		Txt(g, "УДАЛИТЬ ИГРУ?", true, 78, White, 104, 150, In(0.05f));
		TxtBox(g, installDir, false, 22, Silver, new RectangleF(110, 300, 620, 40), StringAlignment.Near, In(0.15f));
		Txt(g, "Сохранения, настройки и музыка iPod останутся,\nесли не отметить галочку.", false, 18, Silver, 110, 360, In(0.2f));
	}

	void DrawButtons(Graphics g)
	{
		for (int i = 0; i < btns.Count; i++)
		{
			Btn b = btns[i];
			float a = b.Small ? fade : In(0.25f + i * 0.045f);
			if (a <= 0.01f) continue;
			float off = (1f - a) * -34f + b.Hover * 10f;
			RectangleF r = new RectangleF(b.R.X + off, b.R.Y, b.R.Width, b.R.Height);
			if (b.Small) { TxtBox(g, b.Text, false, 15, b.Hover > 0.5f ? White : Grey, r, StringAlignment.Far, a); continue; }
			Color c = b.Enabled ? White : Color.FromArgb(80, 82, 86);
			if (b.Hover > 0.02f && b.Enabled)
				Band(g, r.X - 30, r.Y + 4, (r.Width + 30) * Ease(b.Hover), r.Height - 8, 50 + i, a);
			Color tc = b.Hover > 0.5f && b.Enabled ? Ink : c;
			float size = Math.Min(r.Height * 0.74f, 64f);
			if (b.Check)
			{
				using (Pen p = new Pen(Color.FromArgb((int)(255 * a), tc), 3f)) g.DrawRectangle(p, r.X + 6, r.Y + 13, 28, 28);
				if (b.Checked) using (SolidBrush sb = new SolidBrush(Color.FromArgb((int)(255 * a), tc))) g.FillRectangle(sb, r.X + 12, r.Y + 19, 17, 17);
				TxtBox(g, b.Text, false, 24, tc, new RectangleF(r.X + 52, r.Y, r.Width - 56, r.Height), StringAlignment.Near, a);
			}
			else
			{
				using (SolidBrush sb = new SolidBrush(Color.FromArgb((int)(255 * a), tc)))
					g.FillPolygon(sb, new PointF[] { new PointF(r.X + 4, r.Y + r.Height * 0.3f), new PointF(r.X + 4 + size * 0.34f, r.Y + r.Height * 0.5f), new PointF(r.X + 4, r.Y + r.Height * 0.7f) });
				float avail = r.Width - 24 - size * 0.42f;
				Font mf = F(true, size);
				{
					float tw = g.MeasureString(b.Text, mf, 4000, StringFormat.GenericTypographic).Width;
					if (tw > avail) size *= avail / tw;
				}
				TxtBox(g, b.Text, true, size, tc, new RectangleF(r.X + 14 + size * 0.42f, r.Y, r.Width - 14 - size * 0.42f, r.Height), StringAlignment.Near, a);
			}
		}
	}

	// ---------------- снимки всех экранов (для проверки) ----------------
	void Shots()
	{
		Directory.CreateDirectory(shotsDir);
		Size[] sizes = { new Size(1920, 1080), new Size(1366, 768), new Size(2560, 1440), new Size(1280, 800) };
		Scr[] all = { Scr.Intro, Scr.Location, Scr.Options, Scr.Installing, Scr.Complete, Scr.Failed, Scr.Uninstall, Scr.UninstallDone };
		t = 5f; fade = 1f;
		foreach (Size sz in sizes)
			foreach (Scr s in all)
			{
				if (sz.Width != 1920 && sz.Width != 1366 && s != Scr.Intro && s != Scr.Installing) continue;
				scr = s; scrT = 5f;
				Layout2();
				foreach (Btn b in btns) b.Hover = 0f;
				if (btns.Count > 1) btns[0].Hover = 1f;
				if (s == Scr.Installing) { shownPct = 63f; done = 133L * 1048576L; total = 211L * 1048576L; speed = 14.2; filesDone = 1; phase = "EXTRACTING THE GOODS… качаю игру"; }
				if (s == Scr.Complete) resultNote = "Игра и лаунчер установлены. Ярлыки: рабочий стол, меню «Пуск».";
				if (s == Scr.Failed) failText = "Нет связи с GitHub. Проверь интернет и попробуй ещё раз.";
				if (s == Scr.UninstallDone) resultNote = "Сохранения и настройки оставлены.";
				using (Bitmap bmp = new Bitmap(sz.Width, sz.Height))
				{
					using (Graphics g = Graphics.FromImage(bmp)) Draw(g, sz);
					bmp.Save(Path.Combine(shotsDir, sz.Width + "x" + sz.Height + "_" + (int)s + "_" + s + ".png"), ImageFormat.Png);
				}
			}
	}

	// ---------------- сеть ----------------
	Dictionary<string, object> Release()
	{
		HttpWebRequest r = (HttpWebRequest)WebRequest.Create(Api);
		r.UserAgent = UA; r.Accept = "application/vnd.github+json"; r.Timeout = 15000;
		using (WebResponse resp = r.GetResponse())
		using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
		{
			JavaScriptSerializer js = new JavaScriptSerializer();
			js.MaxJsonLength = int.MaxValue;
			return js.Deserialize<Dictionary<string, object>>(sr.ReadToEnd());
		}
	}

	static Dictionary<string, object> Asset(Dictionary<string, object> rel, string n)
	{
		object list;
		if (!rel.TryGetValue("assets", out list)) return null;
		foreach (object o in (ArrayList)list)
		{
			Dictionary<string, object> a = o as Dictionary<string, object>;
			if (a != null && Convert.ToString(a["name"]) == n) return a;
		}
		return null;
	}

	static string Get(Dictionary<string, object> a, string k) { object v; return a.TryGetValue(k, out v) && v != null ? Convert.ToString(v) : ""; }

	static string Stamp(Dictionary<string, object> a)
	{
		string d = Get(a, "digest");
		return d.StartsWith("sha256:") ? d : "id:" + Get(a, "id") + "@" + Get(a, "updated_at");
	}

	static string Sha(string path)
	{
		using (SHA256 h = SHA256.Create())
		using (FileStream f = File.OpenRead(path))
		{
			StringBuilder sb = new StringBuilder("sha256:");
			foreach (byte x in h.ComputeHash(f)) sb.Append(x.ToString("x2"));
			return sb.ToString();
		}
	}

	void ReadBuild(Dictionary<string, object> rel)
	{
		Match m = Regex.Match(Get(rel, "body"), "коммит `([0-9a-f]{7,})`");
		if (m.Success) build = m.Groups[1].Value;
		Dictionary<string, object> archive = Asset(rel, GamePackage.Asset), ga = Asset(rel, GameAsset), la = Asset(rel, LauncherAsset);
		long n = 0;
		if (ga != null) n += Convert.ToInt64(ga["size"]);
		if (archive != null) n += Convert.ToInt64(archive["size"]) + 16L * 1048576L;
		if (la != null) n += Convert.ToInt64(la["size"]);
		if (n > 0) needBytes = n + 12L * 1048576L;     // запас: файл качается рядом и потом подменяет старый
	}

	void FetchBuild()
	{
		try { ReadBuild(Release()); } catch { }
	}

	class Cancelled : Exception { }

	void Download(Dictionary<string, object> asset, string target)
	{
		string part = target + ".part";
		Stopwatch sw = Stopwatch.StartNew();
		long size = Convert.ToInt64(asset["size"]);
		long last = 0;
		object gate = new object();
		try
		{
			// сразу несколько частей параллельно (..\launcher\FastDownload.cs); счётчик done общий на весь установщик
			FastDownload.Get(Get(asset, "browser_download_url"), part, size, UA, delegate (long got)
			{
				long add;
				lock (gate) { add = got - last; if (add > 0) last = got; }     // части сообщают вразнобой — счёт только вперёд
				if (add > 0) Interlocked.Add(ref done, add);
				speed = got / 1048576.0 / Math.Max(0.2, sw.Elapsed.TotalSeconds);
			}, delegate () { return cancel; });
			if (new FileInfo(part).Length != Convert.ToInt64(asset["size"])) throw new Exception("файл скачался не полностью");
			string dg = Get(asset, "digest");
			if (dg.StartsWith("sha256:"))
			{
				phase = "CHECKING THE GOODS… проверяю файл";
				if (Sha(part) != dg) throw new Exception("контрольная сумма не совпала — попробуй ещё раз");
			}
			if (File.Exists(target)) File.Delete(target);
			File.Move(part, target);
		}
		catch (OperationCanceledException)
		{
			try { if (File.Exists(part)) File.Delete(part); } catch { }
			throw new Cancelled();
		}
		catch
		{
			try { if (File.Exists(part)) File.Delete(part); } catch { }
			throw;
		}
	}

	// ---------------- установка ----------------
	void StartInstall()
	{
		cancel = false; working = true; failText = ""; resultNote = "";
		done = 0; total = 0; speed = 0; filesDone = 0; shownPct = 0;
		phase = "CONNECTING TO THE CLOUD… связь с GitHub";
		Thread th = new Thread(InstallWork);
		th.IsBackground = true;
		th.Start();
	}

	void InstallWork()
	{
		bool created = !Directory.Exists(installDir);
		try
		{
			if (WinBuild() < 10240) throw new Exception("Нужна Windows 10 или новее, 64 бита.");
			if (!Environment.Is64BitOperatingSystem) throw new Exception("Нужна 64-битная Windows.");
			Dictionary<string, object> rel = Release();
			ReadBuild(rel);
			Dictionary<string, object> archive = Asset(rel, GamePackage.Asset);
			Dictionary<string, object> ga = archive ?? Asset(rel, GameAsset), la = Asset(rel, LauncherAsset);
			if (ga == null || la == null) throw new Exception("В релизе сейчас нет файлов игры — похоже, сборка обновляется. Попробуй через пару минут.");
			string why;
			if (!DirOk(out why)) throw new Exception(why);
			Directory.CreateDirectory(installDir);
			string game = Path.Combine(installDir, GameFile), launcher = Path.Combine(installDir, LauncherFile);
			string gStamp = Stamp(ga);
			bool sameGame = optPrev && (archive == null ? File.Exists(game) : GamePackage.Installed(installDir)) && File.Exists(Path.Combine(installDir, "installed.txt")) && File.ReadAllText(Path.Combine(installDir, "installed.txt")).Trim() == gStamp;
			total = (sameGame ? 0 : Convert.ToInt64(ga["size"])) + Convert.ToInt64(la["size"]);
			if (sameGame) { filesDone++; resultNote = "Игра уже последней версии — заново не качалась. "; }
			else
			{
				phase = (File.Exists(game) ? "UPDATING GRIMERKA… качаю новую версию" : "EXTRACTING THE GOODS… качаю игру");
				if (archive == null) Download(ga, game);
				else
				{
					try
					{
						GamePackage.Update(installDir, delegate (string file) { Download(ga, file); phase = "EXTRACTING THE GOODS… распаковываю игру"; }, delegate { return cancel; });
					}
					catch (OperationCanceledException) { throw new Cancelled(); }
				}
				File.WriteAllText(Path.Combine(installDir, "installed.txt"), gStamp);
				filesDone++;
			}
			if (cancel) throw new Cancelled();
			phase = "PREPARING THE UNDERGROUND… качаю лаунчер";
			Download(la, launcher);
			filesDone++;
			phase = "INSTALLING GRIMERKA… ярлыки и запись об удалении";
			File.WriteAllText(Path.Combine(installDir, Marker), "installed by setup\r\n");
			string un = Path.Combine(installDir, UninstFile);
			if (!string.Equals(Long(Application.ExecutablePath), Long(un), StringComparison.OrdinalIgnoreCase))
				File.Copy(Application.ExecutablePath, un, true);
			filesDone++;
			List<string> made = new List<string>();
			if (optDesktop) { Shortcut(DesktopLnk, launcher, game); made.Add("рабочий стол"); } else TryDelete(DesktopLnk);
			if (optStart) { Shortcut(StartLnk, launcher, game); made.Add("меню «Пуск»"); } else TryDelete(StartLnk);
			using (RegistryKey k = Registry.CurrentUser.CreateSubKey(UninstKey))
			{
				k.SetValue("DisplayName", name);
				k.SetValue("DisplayIcon", game);
				k.SetValue("InstallLocation", installDir);
				k.SetValue("UninstallString", "\"" + un + "\" --uninstall" + (id != "GodOfGrimerka" ? " --id=" + id : ""));
				k.SetValue("Publisher", "jelos8vetoi & rofaan");
				k.SetValue("DisplayVersion", build != "" ? build : "godot-build");
				k.SetValue("GrimerkaStamp", gStamp);
				k.SetValue("NoModify", 1, RegistryValueKind.DWord);
				k.SetValue("NoRepair", 1, RegistryValueKind.DWord);
				k.SetValue("EstimatedSize", (int)(needBytes / 1024), RegistryValueKind.DWord);
			}
			phase = "ALMOST THERE…";
			resultNote += "Папка: " + installDir + ". Ярлыки: " + (made.Count > 0 ? string.Join(", ", made.ToArray()) : "нет") + ".";
			if (auto && optLaunch) LaunchGame();
		}
		catch (Cancelled)
		{
			failText = "Установка отменена. Недокачанный файл удалён, уже установленное не тронуто.";
			try { if (created && Directory.Exists(installDir) && Directory.GetFileSystemEntries(installDir).Length == 0) Directory.Delete(installDir); } catch { }
		}
		catch (WebException e) { failText = "Нет связи с GitHub: " + e.Message; }
		catch (UnauthorizedAccessException) { failText = "Нет прав на запись в эту папку. Выбери другую (например, в своей папке пользователя) или закрой игру, если она запущена."; }
		catch (IOException e) { failText = "Не удалось записать файл: " + e.Message + " Если игра запущена — закрой её."; }
		catch (Exception e) { failText = e.Message; }
		working = false;
	}

	[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
	static extern int GetLongPathName(string shortPath, StringBuilder longPath, int size);

	// Полный путь без коротких имён вида USERNA~1 и без хвостового слэша — чтобы сравнивать папки.
	static string Long(string path)
	{
		string full = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar);
		StringBuilder sb = new StringBuilder(1024);
		int n = GetLongPathName(full, sb, sb.Capacity);
		return n > 0 && n < sb.Capacity ? sb.ToString().TrimEnd(Path.DirectorySeparatorChar) : full;
	}

	// Номер сборки Windows из реестра: Environment.OSVersion без манифеста на Windows 10/11 отвечает «6.2».
	static int WinBuild()
	{
		try
		{
			using (RegistryKey k = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion"))
				return int.Parse(Convert.ToString(k.GetValue("CurrentBuildNumber", "0")));
		}
		catch { return 99999; }
	}

	string DesktopLnk { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), name + ".lnk"); } }
	string StartLnk { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), name + ".lnk"); } }

	static void TryDelete(string p) { try { if (File.Exists(p)) File.Delete(p); } catch { } }

	void Shortcut(string lnk, string target, string icon)
	{
		Type tp = Type.GetTypeFromProgID("WScript.Shell");
		object sh = Activator.CreateInstance(tp);
		object sc = tp.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, sh, new object[] { lnk });
		Type st = sc.GetType();
		st.InvokeMember("TargetPath", BindingFlags.SetProperty, null, sc, new object[] { target });
		st.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, sc, new object[] { installDir });
		st.InvokeMember("IconLocation", BindingFlags.SetProperty, null, sc, new object[] { icon + ",0" });
		st.InvokeMember("Description", BindingFlags.SetProperty, null, sc, new object[] { "GOD OF GRIMERKA" });
		st.InvokeMember("Save", BindingFlags.InvokeMethod, null, sc, null);
	}

	void LaunchGame()
	{
		try
		{
			ProcessStartInfo p = new ProcessStartInfo(Path.Combine(installDir, LauncherFile));
			p.WorkingDirectory = installDir;
			Process.Start(p);
		}
		catch { }
	}

	// ---------------- удаление ----------------
	void DoUninstall()
	{
		List<string> left = new List<string>();
		var files = new List<string>(GamePackage.Files) { LauncherFile, "installed.txt", Marker, GameFile + ".part", LauncherFile + ".part", LauncherFile + ".new" };
		foreach (string f in files)
		{
			string p = Path.Combine(installDir, f);
			try { if (File.Exists(p)) File.Delete(p); } catch { left.Add(f); }
		}
		TryDelete(DesktopLnk);
		TryDelete(StartLnk);
		try { Registry.CurrentUser.DeleteSubKeyTree(UninstKey, false); } catch { }
		bool wiped = false;
		if (wipeData)
			try { if (Directory.Exists(DataDir)) { Directory.Delete(DataDir, true); wiped = true; } } catch { }
		// сам Uninstall.exe и пустую папку убирает маленький сценарий после выхода (чужие файлы в папке не трогает)
		string self = Application.ExecutablePath;
		if (string.Equals(Long(Path.GetDirectoryName(self)), Long(installDir), StringComparison.OrdinalIgnoreCase))
		{
			string cmd = Path.Combine(Path.GetTempPath(), "grimerka-uninstall-" + Process.GetCurrentProcess().Id + ".cmd");
			File.WriteAllText(cmd, "@echo off\r\nchcp 65001 >nul\r\nfor /l %%i in (1,1,30) do (\r\n  del /f /q \"" + self + "\" >nul 2>&1\r\n  if not exist \"" + self + "\" goto gone\r\n  ping -n 2 127.0.0.1 >nul\r\n)\r\n:gone\r\nrmdir \"" + installDir + "\" >nul 2>&1\r\ndel \"%~f0\"\r\n", new UTF8Encoding(false));
			ProcessStartInfo p = new ProcessStartInfo("cmd.exe", "/c \"" + cmd + "\"");
			p.WindowStyle = ProcessWindowStyle.Hidden; p.CreateNoWindow = true;
			Process.Start(p);
		}
		else
		{
			TryDelete(Path.Combine(installDir, UninstFile));
			try { if (Directory.Exists(installDir) && Directory.GetFileSystemEntries(installDir).Length == 0) Directory.Delete(installDir); } catch { }
		}
		resultNote = (wiped ? "Сохранения и настройки тоже удалены." : "Сохранения, настройки и музыка iPod оставлены.") + (left.Count > 0 ? " Не удалось удалить: " + string.Join(", ", left.ToArray()) + " (игра запущена?)." : "");
	}
}

// Быстрое скачивание файла из релиза GitHub — общее для лаунчера и установщика.
// Файл качается сразу несколькими частями (HTTP Range) в одну заготовку нужного размера: один поток у GitHub
// часто упирается в несколько МБ/с, а 8 потоков забирают канал целиком. Оборвалась часть — она докачивается
// с того места, где встала (до 4 попыток). Сервер не умеет Range или файл маленький — обычное скачивание одним потоком.
// Прогресс — через progress(скачано байт); отмена — cancel() == true (бросает OperationCanceledException).
using System;
using System.IO;
using System.Net;
using System.Threading;

static class FastDownload
{
	public const int Parts = 8;
	const long MinSplit = 16L * 1048576L;          // меньше 16 МБ — одним потоком, части не окупаются
	const int Buf = 1 << 20;

	// один раз на процесс: .NET Framework по умолчанию держит всего 2 соединения на сервер
	public static void Setup()
	{
		ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
		ServicePointManager.DefaultConnectionLimit = Math.Max(ServicePointManager.DefaultConnectionLimit, 32);
		ServicePointManager.Expect100Continue = false;
		ServicePointManager.UseNagleAlgorithm = false;
	}

	public static void Get(string url, string part, long size, string ua, Action<long> progress, Func<bool> cancel)
	{
		Setup();
		string real = Resolve(url, ua);              // ссылка релиза уводит на CDN; части берём сразу оттуда
		if (size >= MinSplit && SupportsRange(real, ua))
			Split(real, part, size, ua, progress, cancel);
		else
			Single(real, part, ua, progress, cancel);
	}

	static HttpWebRequest Req(string url, string ua)
	{
		HttpWebRequest r = (HttpWebRequest)WebRequest.Create(url);
		r.UserAgent = ua;
		r.Timeout = 30000;
		r.ReadWriteTimeout = 60000;
		r.AutomaticDecompression = DecompressionMethods.None;
		return r;
	}

	static string Resolve(string url, string ua)
	{
		try
		{
			for (int hop = 0; hop < 5; hop++)
			{
				HttpWebRequest r = Req(url, ua);
				r.Method = "HEAD";
				r.AllowAutoRedirect = false;
				using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse())
				{
					int code = (int)resp.StatusCode;
					string loc = resp.Headers["Location"];
					if (code >= 300 && code < 400 && !string.IsNullOrEmpty(loc))
					{
						url = new Uri(new Uri(url), loc).ToString();
						continue;
					}
					return url;
				}
			}
		}
		catch { }
		return url;
	}

	static bool SupportsRange(string url, string ua)
	{
		try
		{
			HttpWebRequest r = Req(url, ua);
			r.AddRange(0L, 0L);
			using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse())
				return resp.StatusCode == HttpStatusCode.PartialContent;
		}
		catch { return false; }
	}

	static void Single(string url, string part, string ua, Action<long> progress, Func<bool> cancel)
	{
		long done = 0;
		using (WebResponse resp = Req(url, ua).GetResponse())
		using (Stream src = resp.GetResponseStream())
		using (FileStream dst = new FileStream(part, FileMode.Create, FileAccess.Write, FileShare.None, Buf))
		{
			byte[] buf = new byte[Buf];
			int n;
			while ((n = src.Read(buf, 0, buf.Length)) > 0)
			{
				if (cancel != null && cancel()) throw new OperationCanceledException();
				dst.Write(buf, 0, n);
				done += n;
				if (progress != null) progress(done);
			}
		}
	}

	static void Split(string url, string part, long size, string ua, Action<long> progress, Func<bool> cancel)
	{
		using (FileStream f = new FileStream(part, FileMode.Create, FileAccess.Write, FileShare.ReadWrite))
			f.SetLength(size);
		long chunk = (size + Parts - 1) / Parts;
		long total = 0;
		Exception error = null;
		Thread[] threads = new Thread[Parts];
		for (int i = 0; i < Parts; i++)
		{
			long from = i * chunk, to = Math.Min(size, from + chunk) - 1;
			threads[i] = new Thread(delegate ()
			{
				try
				{
					long pos = from;
					for (int attempt = 0; pos <= to; attempt++)
					{
						try
						{
							HttpWebRequest r = Req(url, ua);
							r.AddRange(pos, to);
							using (HttpWebResponse resp = (HttpWebResponse)r.GetResponse())
							{
								if (resp.StatusCode != HttpStatusCode.PartialContent)
									throw new Exception("сервер не отдал часть файла");
								using (Stream src = resp.GetResponseStream())
								using (FileStream dst = new FileStream(part, FileMode.Open, FileAccess.Write, FileShare.ReadWrite, Buf))
								{
									dst.Position = pos;
									byte[] buf = new byte[Buf];
									int n;
									while (pos <= to && (n = src.Read(buf, 0, (int)Math.Min(buf.Length, to - pos + 1))) > 0)
									{
										if (error != null) return;
										if (cancel != null && cancel()) throw new OperationCanceledException();
										dst.Write(buf, 0, n);
										pos += n;
										long t = Interlocked.Add(ref total, n);
										if (progress != null) progress(t);
									}
								}
							}
						}
						catch (OperationCanceledException) { throw; }
						catch
						{
							if (attempt >= 3) throw;
							Thread.Sleep(800 * (attempt + 1));   // обрыв — докачать эту часть с того же места
						}
					}
				}
				catch (Exception e) { if (error == null) error = e; }
			});
			threads[i].IsBackground = true;
			threads[i].Start();
		}
		foreach (Thread t in threads) t.Join();
		if (error != null) throw error is OperationCanceledException ? error : new Exception("часть файла не скачалась: " + error.Message);
		if (Interlocked.Read(ref total) != size) throw new Exception("файл скачался не полностью");
	}
}

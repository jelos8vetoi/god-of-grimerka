using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;

static class GamePackage
{
    internal const string Asset = "GOD-OF-GRIMERKA-Windows-x64.zip";
    internal const string Exe = "GOD OF GRIMERKA.exe";
    internal static readonly string[] Files = {
        "discord_partner_sdk.dll",
        "discord_social_sdk.windows.template_release.x86_64.dll",
        "Discord-SDK-LICENSE.txt",
        "Discord-SDK-Notices.txt",
        Exe
    };

    internal static bool Installed(string directory)
    {
        foreach (string file in Files)
            if (!File.Exists(Path.Combine(directory, file))) return false;
        return true;
    }

    internal static void Update(string directory, Action<string> download, Func<bool> cancelled)
    {
        string mutexFile = Path.Combine(directory, ".game-update.lock");
        using (var updateLock = new FileStream(mutexFile, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None, 1, FileOptions.DeleteOnClose))
            Apply(directory, download, cancelled);
    }

    private static void Apply(string directory, Action<string> download, Func<bool> cancelled)
    {
        string stage = Path.Combine(directory, ".game-update-" + Guid.NewGuid().ToString("N"));
        string archive = Path.Combine(stage, Asset);
        Directory.CreateDirectory(stage);
        var changed = new List<string>();
        bool keepRecovery = false;
        try
        {
            download(archive);
            using (var zip = new ZipArchive(File.OpenRead(archive), ZipArchiveMode.Read))
            {
                if (zip.Entries.Count != Files.Length)
                    throw new InvalidDataException("Состав архива игры не совпадает с ожидаемым.");
                foreach (string file in Files)
                {
                    ZipArchiveEntry entry = zip.GetEntry(file);
                    if (entry == null || entry.Length == 0)
                        throw new InvalidDataException("В архиве игры отсутствует " + file);
                    using (Stream input = entry.Open())
                    using (Stream output = File.Create(Path.Combine(stage, file)))
                    {
                        byte[] buffer = new byte[128 * 1024];
                        int read;
                        while ((read = input.Read(buffer, 0, buffer.Length)) != 0)
                        {
                            if (cancelled != null && cancelled()) throw new OperationCanceledException();
                            output.Write(buffer, 0, read);
                        }
                        if (output.Length != entry.Length)
                            throw new InvalidDataException("Файл извлечён не полностью: " + file);
                    }
                }
            }

            // The executable is replaced last, after all sidecar files are in place.
            foreach (string file in Files)
            {
                string staged = Path.Combine(stage, file);
                string target = Path.Combine(directory, file);
                if (File.Exists(target))
                    File.Replace(staged, target, staged + ".previous");
                else
                    File.Move(staged, target);
                changed.Add(file);
            }
        }
        catch
        {
            changed.Reverse();
            try
            {
                foreach (string file in changed)
                {
                    string target = Path.Combine(directory, file);
                    string previous = Path.Combine(stage, file + ".previous");
                    if (File.Exists(previous)) File.Replace(previous, target, null);
                    else File.Delete(target);
                }
            }
            catch
            {
                keepRecovery = true;
                throw;
            }
            throw;
        }
        finally
        {
            // The directory contains only files created by this update.
            if (!keepRecovery)
                try { Directory.Delete(stage, true); } catch (IOException) { } catch (UnauthorizedAccessException) { }
        }
    }
}

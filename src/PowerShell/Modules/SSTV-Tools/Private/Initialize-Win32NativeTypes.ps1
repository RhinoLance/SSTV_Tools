function Initialize-Win32NativeTypes {
	[CmdletBinding()]
	param()

	if ("SSTVToolsWin32" -as [type]) {
		return
	}

	$win32 = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class SSTVToolsWin32 {
	public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
	public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

	[DllImport("gdi32.dll")]
	public static extern bool BitBlt(IntPtr hdcDest, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hdcSrc, int nXSrc, int nYSrc, int dwRop);
	[DllImport("gdi32.dll")]
	public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);
	[DllImport("gdi32.dll")]
	public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
	[DllImport("gdi32.dll")]
	public static extern bool DeleteDC(IntPtr hdc);
	[DllImport("gdi32.dll")]
	public static extern bool DeleteObject(IntPtr hObject);
	[DllImport("gdi32.dll")]
	public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);

	[DllImport("user32.dll")]
	public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
	[DllImport("user32.dll")]
	public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
	[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
	public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern int GetWindowTextLength(IntPtr hWnd);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
	[DllImport("user32.dll")]
	public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
	[DllImport("user32.dll")]
	public static extern IntPtr GetParent(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern IntPtr GetWindowDC(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
	[DllImport("user32.dll")]
	[return: MarshalAs(UnmanagedType.Bool)]
	public static extern bool IsWindowVisible(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern bool IsIconic(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
	[DllImport("user32.dll")]
	public static extern bool SetForegroundWindow(IntPtr hWnd);
	[DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags
    );
	[DllImport("user32.dll")]
	public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

	Add-Type -TypeDefinition $win32 -ErrorAction Stop | Out-Null
}

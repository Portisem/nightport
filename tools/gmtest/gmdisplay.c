/* gmdisplay: qué monitores, resolución y DPI reporta Wine a los programas. */
#define _WIN32_WINNT 0x0A00
#include <windows.h>
#include <stdio.h>
static BOOL CALLBACK cb(HMONITOR m, HDC dc, LPRECT r, LPARAM p)
{
    MONITORINFOEXA mi = { sizeof(mi) };
    GetMonitorInfoA(m, (MONITORINFO *)&mi);
    printf("monitor %s: rc=(%ld,%ld)-(%ld,%ld) work=(%ld,%ld)-(%ld,%ld) primary=%d\n", mi.szDevice,
           mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right, mi.rcMonitor.bottom,
           mi.rcWork.left, mi.rcWork.top, mi.rcWork.right, mi.rcWork.bottom, !!(mi.dwFlags & MONITORINFOF_PRIMARY));
    return TRUE;
}
int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("screen %dx%d virtual (%d,%d) %dx%d monitors=%d dpi=%u\n", GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN),
           GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN), GetSystemMetrics(SM_CXVIRTUALSCREEN),
           GetSystemMetrics(SM_CYVIRTUALSCREEN), GetSystemMetrics(SM_CMONITORS), GetDpiForSystem());
    EnumDisplayMonitors(NULL, NULL, cb, 0);
    DISPLAY_DEVICEA dd = { sizeof(dd) };
    for (DWORD i = 0; EnumDisplayDevicesA(NULL, i, &dd, 0); i++)
        printf("device %lu: %s '%s' flags=%#lx\n", i, dd.DeviceName, dd.DeviceString, dd.StateFlags);
    return 0;
}

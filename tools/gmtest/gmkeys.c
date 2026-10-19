/* gmkeys: automatiza la entrada de un juego dentro de Wine (pruebas sin manos).
 *
 *   gmkeys.exe "<título de ventana (subcadena)>" paso paso ...
 *
 * Pasos:
 *   key:NAME     pulsa y suelta una tecla (RETURN, ESCAPE, UP, DOWN, LEFT, RIGHT, SPACE, TAB, A..Z, 0..9, F1..F12)
 *   hold:NAME:ms mantiene una tecla
 *   click:X,Y    clic izquierdo en coordenadas del área cliente
 *   move:X,Y     mueve el ratón
 *   wait:ms      espera
 *
 * Usa SendInput con scancodes: llega a la cola de entrada de Wine igual que un teclado real.
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static HWND target;
static const char *needle;

static BOOL CALLBACK find(HWND h, LPARAM p)
{
    char t[256];
    if (!IsWindowVisible(h)) return TRUE;
    GetWindowTextA(h, t, sizeof(t));
    if (strstr(t, needle)) { target = h; return FALSE; }
    return TRUE;
}

static WORD vk_from_name(const char *n)
{
    static const struct { const char *name; WORD vk; } map[] = {
        {"RETURN", VK_RETURN}, {"ENTER", VK_RETURN}, {"ESCAPE", VK_ESCAPE}, {"ESC", VK_ESCAPE},
        {"UP", VK_UP}, {"DOWN", VK_DOWN}, {"LEFT", VK_LEFT}, {"RIGHT", VK_RIGHT},
        {"SPACE", VK_SPACE}, {"TAB", VK_TAB}, {"BACK", VK_BACK}, {"SHIFT", VK_SHIFT},
        {"CONTROL", VK_CONTROL}, {"ALT", VK_MENU},
    };
    for (size_t i = 0; i < sizeof(map) / sizeof(map[0]); i++) if (!_stricmp(n, map[i].name)) return map[i].vk;
    if (strlen(n) == 1) return (WORD)toupper((unsigned char)n[0]);
    if ((n[0] == 'F' || n[0] == 'f') && atoi(n + 1) >= 1 && atoi(n + 1) <= 12) return VK_F1 + atoi(n + 1) - 1;
    return 0;
}

static BOOL extended(WORD vk)
{
    return vk == VK_UP || vk == VK_DOWN || vk == VK_LEFT || vk == VK_RIGHT;
}

static void key_event(WORD vk, BOOL up)
{
    INPUT in = {0};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = vk;
    in.ki.wScan = (WORD)MapVirtualKeyA(vk, MAPVK_VK_TO_VSC);
    in.ki.dwFlags = KEYEVENTF_SCANCODE | (up ? KEYEVENTF_KEYUP : 0) | (extended(vk) ? KEYEVENTF_EXTENDEDKEY : 0);
    SendInput(1, &in, sizeof(in));
}

static void mouse_to(int x, int y)
{
    POINT pt = { x, y };
    ClientToScreen(target, &pt);
    SetCursorPos(pt.x, pt.y);
}

static void click(void)
{
    INPUT in[2] = {0};
    in[0].type = in[1].type = INPUT_MOUSE;
    in[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    in[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    SendInput(1, &in[0], sizeof(INPUT));
    Sleep(60);
    SendInput(1, &in[1], sizeof(INPUT));
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc < 2) { printf("uso: gmkeys \"titulo\" paso...\n"); return 2; }
    needle = argv[1];
    EnumWindows(find, 0);
    if (!target) { printf("no encontré ventana con '%s'\n", needle); return 1; }
    SetForegroundWindow(target);
    SetFocus(target);
    Sleep(300);
    for (int i = 2; i < argc; i++)
    {
        char *a = argv[i];
        if (!strncmp(a, "wait:", 5)) Sleep(atoi(a + 5));
        else if (!strncmp(a, "key:", 4) || !strncmp(a, "hold:", 5))
        {
            BOOL hold = a[0] == 'h';
            char name[32] = {0};
            strncpy(name, a + (hold ? 5 : 4), sizeof(name) - 1);
            char *colon = strchr(name, ':');
            int ms = 80;
            if (colon) { *colon = 0; ms = atoi(colon + 1); }
            WORD vk = vk_from_name(name);
            if (!vk) { printf("tecla desconocida: %s\n", name); continue; }
            key_event(vk, FALSE); Sleep(ms); key_event(vk, TRUE);
            Sleep(120);
        }
        else if (!strncmp(a, "click:", 6) || !strncmp(a, "move:", 5))
        {
            int x, y;
            if (sscanf(strchr(a, ':') + 1, "%d,%d", &x, &y) == 2)
            {
                mouse_to(x, y);
                Sleep(80);
                if (a[0] == 'c') click();
            }
        }
        printf("ok %s\n", a);
    }
    return 0;
}

/* gmnet: prueba de red dentro de Wine (DNS + HTTP por IPv4 e IPv6), como el connectivity test de Steam. */
#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdio.h>

static double now_ms(void){ LARGE_INTEGER f,c; QueryPerformanceFrequency(&f); QueryPerformanceCounter(&c); return c.QuadPart*1000.0/f.QuadPart; }

static void try_family(const char *host, int family)
{
    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = family; hints.ai_socktype = SOCK_STREAM;
    double t0 = now_ms();
    int r = getaddrinfo(host, "80", &hints, &res);
    printf("[%s] getaddrinfo(%s) = %d en %.0f ms\n", family == AF_INET6 ? "IPv6" : "IPv4", host, r, now_ms() - t0);
    if (r || !res) return;
    char buf[64]; DWORD len = sizeof(buf);
    WSAAddressToStringA(res->ai_addr, (DWORD)res->ai_addrlen, NULL, buf, &len);
    SOCKET s = socket(res->ai_family, SOCK_STREAM, IPPROTO_TCP);
    DWORD tmo = 5000; setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, (char *)&tmo, sizeof(tmo));
    t0 = now_ms();
    r = connect(s, res->ai_addr, (int)res->ai_addrlen);
    printf("  connect %s = %d (err %d) en %.0f ms\n", buf, r, r ? WSAGetLastError() : 0, now_ms() - t0);
    if (!r)
    {
        char req[256]; snprintf(req, sizeof(req), "GET /204 HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n", host);
        send(s, req, (int)strlen(req), 0);
        char resp[128] = {0}; t0 = now_ms();
        int n = recv(s, resp, sizeof(resp) - 1, 0);
        char *nl = strchr(resp, '\r'); if (nl) *nl = 0;
        printf("  respuesta (%d bytes, %.0f ms): %s\n", n, now_ms() - t0, resp);
    }
    closesocket(s); freeaddrinfo(res);
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    WSADATA w; WSAStartup(MAKEWORD(2,2), &w);
    const char *host = argc > 1 ? argv[1] : "steamconnecttest.com";
    try_family(host, AF_INET);
    try_family(host, AF_INET6);
    double t0 = now_ms(); struct addrinfo *res = NULL;
    int r = getaddrinfo("wpad", NULL, NULL, &res);
    printf("getaddrinfo(wpad) = %d en %.0f ms\n", r, now_ms() - t0);
    return 0;
}

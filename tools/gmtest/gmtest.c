/* gmtest: prueba mínima de traductores gráficos (DX11 / DX12) para GamingMac.
 *
 *   gmtest.exe dx11 [frames]   crea device + swapchain D3D11, limpia N frames, mide FPS
 *   gmtest.exe dx12 [frames]   igual con D3D12 (cola, allocator, lista de comandos, fence)
 *
 * Imprime el adaptador que ve el juego (nombre, VRAM, vendor) y los FPS de presentación.
 * Compilar: x86_64-w64-mingw32-clang -O2 gmtest.c -o gmtest.exe -ld3d11 -ld3d12 -ldxgi -luser32 -lgdi32
 */
#define COBJMACROS
#define INITGUID
#define WIDL_C_INLINE_WRAPPERS
#include <windows.h>
#include <stdio.h>
#include <d3d11.h>
#include <d3d12.h>
#include <dxgi1_4.h>

static LRESULT CALLBACK wndproc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    if (m == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(h, m, w, l);
}

static HWND make_window(const wchar_t *title)
{
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = wndproc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = L"gmtest";
    RegisterClassW(&wc);
    HWND hwnd = CreateWindowW(L"gmtest", title, WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                              100, 100, 1280, 720, NULL, NULL, wc.hInstance, NULL);
    return hwnd;
}

static void pump(void)
{
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessageW(&msg); }
}

static void print_adapter(IDXGIAdapter *adapter)
{
    DXGI_ADAPTER_DESC d;
    if (SUCCEEDED(IDXGIAdapter_GetDesc(adapter, &d)))
        printf("adapter: %ls | vendor 0x%04x device 0x%04x | VRAM %llu MB | shared %llu MB\n",
               d.Description, d.VendorId, d.DeviceId,
               (unsigned long long)d.DedicatedVideoMemory >> 20, (unsigned long long)d.SharedSystemMemory >> 20);
}

static double now_ms(void)
{
    LARGE_INTEGER f, c;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart * 1000.0 / (double)f.QuadPart;
}

static int test_dx11(int frames)
{
    HWND hwnd = make_window(L"gmtest dx11");
    DXGI_SWAP_CHAIN_DESC sd = {0};
    sd.BufferCount = 2;
    sd.BufferDesc.Width = 1280;
    sd.BufferDesc.Height = 720;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;

    ID3D11Device *dev; ID3D11DeviceContext *ctx; IDXGISwapChain *sc; D3D_FEATURE_LEVEL fl;
    HRESULT hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0,
                                               D3D11_SDK_VERSION, &sd, &sc, &dev, &fl, &ctx);
    if (FAILED(hr)) { printf("FAIL D3D11CreateDeviceAndSwapChain hr=0x%08lx\n", hr); return 1; }
    printf("dx11: feature level 0x%x\n", fl);

    IDXGIDevice *dxgidev; IDXGIAdapter *adapter;
    if (SUCCEEDED(ID3D11Device_QueryInterface(dev, &IID_IDXGIDevice, (void **)&dxgidev)) &&
        SUCCEEDED(IDXGIDevice_GetAdapter(dxgidev, &adapter)))
        print_adapter(adapter);

    ID3D11Texture2D *bb; ID3D11RenderTargetView *rtv;
    IDXGISwapChain_GetBuffer(sc, 0, &IID_ID3D11Texture2D, (void **)&bb);
    ID3D11Device_CreateRenderTargetView(dev, (ID3D11Resource *)bb, NULL, &rtv);

    double t0 = now_ms();
    for (int i = 0; i < frames; i++)
    {
        float c[4] = { (i % 120) / 120.0f, 0.3f, 0.6f, 1.0f };
        ID3D11DeviceContext_OMSetRenderTargets(ctx, 1, &rtv, NULL);
        ID3D11DeviceContext_ClearRenderTargetView(ctx, rtv, c);
        IDXGISwapChain_Present(sc, 0, 0);
        pump();
    }
    double ms = now_ms() - t0;
    printf("dx11: %d frames en %.0f ms = %.1f FPS (sin vsync)\nOK dx11\n", frames, ms, frames * 1000.0 / ms);
    return 0;
}

static int test_dx12(int frames)
{
    HWND hwnd = make_window(L"gmtest dx12");
    IDXGIFactory4 *factory; IDXGIAdapter1 *adapter = NULL;
    HRESULT hr = CreateDXGIFactory2(0, &IID_IDXGIFactory4, (void **)&factory);
    if (FAILED(hr)) { printf("FAIL CreateDXGIFactory2 hr=0x%08lx\n", hr); return 1; }
    IDXGIFactory1_EnumAdapters1((IDXGIFactory1 *)factory, 0, &adapter);
    if (adapter) print_adapter((IDXGIAdapter *)adapter);

    ID3D12Device *dev;
    hr = D3D12CreateDevice((IUnknown *)adapter, D3D_FEATURE_LEVEL_12_0, &IID_ID3D12Device, (void **)&dev);
    if (FAILED(hr)) { printf("FAIL D3D12CreateDevice hr=0x%08lx\n", hr); return 1; }

    D3D12_FEATURE_DATA_D3D12_OPTIONS5 o5 = {0};
    if (SUCCEEDED(ID3D12Device_CheckFeatureSupport(dev, D3D12_FEATURE_D3D12_OPTIONS5, &o5, sizeof(o5))))
        printf("dx12: raytracing tier %d\n", o5.RaytracingTier);

    D3D12_COMMAND_QUEUE_DESC qd = { D3D12_COMMAND_LIST_TYPE_DIRECT };
    ID3D12CommandQueue *queue;
    ID3D12Device_CreateCommandQueue(dev, &qd, &IID_ID3D12CommandQueue, (void **)&queue);

    DXGI_SWAP_CHAIN_DESC1 sd = {0};
    sd.Width = 1280; sd.Height = 720;
    sd.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.SampleDesc.Count = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.BufferCount = 2;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    IDXGISwapChain1 *sc1; IDXGISwapChain3 *sc;
    hr = IDXGIFactory2_CreateSwapChainForHwnd((IDXGIFactory2 *)factory, (IUnknown *)queue, hwnd, &sd, NULL, NULL, &sc1);
    if (FAILED(hr)) { printf("FAIL CreateSwapChainForHwnd hr=0x%08lx\n", hr); return 1; }
    IDXGISwapChain1_QueryInterface(sc1, &IID_IDXGISwapChain3, (void **)&sc);

    D3D12_DESCRIPTOR_HEAP_DESC hd = { D3D12_DESCRIPTOR_HEAP_TYPE_RTV, 2 };
    ID3D12DescriptorHeap *heap;
    ID3D12Device_CreateDescriptorHeap(dev, &hd, &IID_ID3D12DescriptorHeap, (void **)&heap);
    UINT inc = ID3D12Device_GetDescriptorHandleIncrementSize(dev, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    D3D12_CPU_DESCRIPTOR_HANDLE base;
    base = ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(heap);
    ID3D12Resource *bufs[2];
    for (int i = 0; i < 2; i++)
    {
        D3D12_CPU_DESCRIPTOR_HANDLE h = { base.ptr + i * inc };
        IDXGISwapChain3_GetBuffer(sc, i, &IID_ID3D12Resource, (void **)&bufs[i]);
        ID3D12Device_CreateRenderTargetView(dev, bufs[i], NULL, h);
    }

    ID3D12CommandAllocator *alloc; ID3D12GraphicsCommandList *list; ID3D12Fence *fence;
    ID3D12Device_CreateCommandAllocator(dev, D3D12_COMMAND_LIST_TYPE_DIRECT, &IID_ID3D12CommandAllocator, (void **)&alloc);
    ID3D12Device_CreateCommandList(dev, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, alloc, NULL, &IID_ID3D12GraphicsCommandList, (void **)&list);
    ID3D12GraphicsCommandList_Close(list);
    ID3D12Device_CreateFence(dev, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, (void **)&fence);
    HANDLE ev = CreateEventW(NULL, FALSE, FALSE, NULL);
    UINT64 fv = 0;

    double t0 = now_ms();
    for (int i = 0; i < frames; i++)
    {
        UINT idx = IDXGISwapChain3_GetCurrentBackBufferIndex(sc);
        ID3D12CommandAllocator_Reset(alloc);
        ID3D12GraphicsCommandList_Reset(list, alloc, NULL);
        D3D12_RESOURCE_BARRIER b = {0};
        b.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b.Transition.pResource = bufs[idx];
        b.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        b.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &b);
        D3D12_CPU_DESCRIPTOR_HANDLE h = { base.ptr + idx * inc };
        float c[4] = { 0.2f, (i % 120) / 120.0f, 0.4f, 1.0f };
        ID3D12GraphicsCommandList_ClearRenderTargetView(list, h, c, 0, NULL);
        b.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        b.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        ID3D12GraphicsCommandList_ResourceBarrier(list, 1, &b);
        ID3D12GraphicsCommandList_Close(list);
        ID3D12CommandQueue_ExecuteCommandLists(queue, 1, (ID3D12CommandList **)&list);
        IDXGISwapChain3_Present(sc, 0, 0);
        ID3D12CommandQueue_Signal(queue, fence, ++fv);
        if (ID3D12Fence_GetCompletedValue(fence) < fv)
        {
            ID3D12Fence_SetEventOnCompletion(fence, fv, ev);
            WaitForSingleObject(ev, INFINITE);
        }
        pump();
    }
    double ms = now_ms() - t0;
    printf("dx12: %d frames en %.0f ms = %.1f FPS (sin vsync)\nOK dx12\n", frames, ms, frames * 1000.0 / ms);
    return 0;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    int frames = argc > 2 ? atoi(argv[2]) : 600;
    if (argc > 1 && !strcmp(argv[1], "dx12")) return test_dx12(frames);
    return test_dx11(frames);
}

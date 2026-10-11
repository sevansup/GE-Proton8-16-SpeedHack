#include <windows.h>
#include <stdio.h>

typedef LONG (WINAPI *set_speed_t)(ULONG);

static ULONGLONG wall_time(void)
{
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    return ((ULONGLONG)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
}

static double measure(void)
{
    LARGE_INTEGER begin, end, frequency;
    ULONGLONG wall_begin = wall_time(), wall_end;
    QueryPerformanceFrequency(&frequency);
    QueryPerformanceCounter(&begin);
    do { Sleep(1); wall_end = wall_time(); }
    while (wall_end - wall_begin < 10000000);
    QueryPerformanceCounter(&end);
    return ((double)(end.QuadPart - begin.QuadPart) / frequency.QuadPart) /
           ((double)(wall_end - wall_begin) / 10000000.0);
}

int main(void)
{
    set_speed_t set_speed = (set_speed_t)GetProcAddress(
        GetModuleHandleA("ntdll.dll"), "wine_update_speedhack_multiplier");
    double normal, fast, restored;
    if (!set_speed) { puts("FAIL: speedhack export missing"); return 1; }
    if (set_speed(10)) return 2;
    normal = measure();
    if (set_speed(30)) return 3;
    fast = measure();
    if (set_speed(10)) return 4;
    restored = measure();
    printf("normal=%.3f fast=%.3f restored=%.3f\n", normal, fast, restored);
    if (normal < 0.75 || normal > 1.25 || fast < 2.5 || fast > 3.5 ||
        restored < 0.75 || restored > 1.25) return 5;
    puts("PASS: 1x -> 3x -> 1x timer behavior");
    return 0;
}

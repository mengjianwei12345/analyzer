// PARAM: --set ana.activated[+] "'octApron'" --enable dbg.debug --enable ana.int.interval

int main() {
    int i = 0;
    int x = 10;
    int y = 5;
    int r = x + y;
    while (i < 5) {
        i++;
        if (x > y) x -= y;
        r = r - 1;
    }
    return 0;
}
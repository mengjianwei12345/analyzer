// SKIP PARAM: --set ana.activated[+] apron --set ana.path_sens[+] threadflag --enable ana.int.interval
extern int __VERIFIER_nondet_int();

#include<pthread.h>
int global = 0;

void *t_fun(void *arg)
{
    global = 5;
    assert(1);
}

int main(void)
{
    pthread_t t;
    int i = __VERIFIER_nondet_int(); //rand
    int mt = 0;

    if(i < 1) {
        pthread_create(&t, ((void *)0), t_fun, ((void *)0));
        assert(global == 0); //UNKNOWN!
        i++;
        mt=1;
    } else {
        global = 17;
    }

    if(!mt) {
        if(global<=5) {} else {
            assert(1); // There must be a path that reaches this
        }
    }

    return 0;
}
